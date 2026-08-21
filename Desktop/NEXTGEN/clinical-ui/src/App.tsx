import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  getTimeline,
  sendEvent,
  subscribeProjection,
  examFindingCaptured,
  clinicianDecision,
  listEncounterAlerts,
  type EncounterSummary,
  type SafetyAlert,
} from './api';
import { startEncounter, getEncounterSnapshot } from './clinical/api';
import { buildProjection } from './clinical/runtime';
import {
  type ChiefComplaintInput,
  complaintFactsFromSave,
  isComplaintFactCode,
} from './clinical/complaints';

import type {
  ClinicalEvent,
  EnhancedClinicalRuntimeProjection,
  ConnectionState,
  TabId,
  TimelineEvent,
  ClinicalUIState,
  WorkspaceSectionProjection,
  Alert as AlertType,
} from './types';

import type {
  UniversalClinicalProjection,
  ClinicalFact,
  HistorySectionDefinition,
  CaptureQuestion,
} from './clinical/types';

import { WorkspaceHeader } from './components/WorkspaceHeader';
import { PatientSnapshot } from './components/Workspace/PatientSnapshot';
import { FactsPanel } from './components/Workspace/FactsPanel';
import { AlertsBanner } from './components/Alerts/AlertsBanner';
import { ReasoningDrawer } from './components/Reasoning/ReasoningDrawer';
import { ExamWorkspace } from './components/Examination/ExamWorkspace';
import { InvestigationCenter } from './components/Investigations/InvestigationCenter';
import { ManagementCenter } from './components/Management/ManagementCenter';
import { MonitoringCenter } from './components/Monitoring/MonitoringCenter';
import { DocumentationCenter } from './components/Documentation/DocumentationCenter';
import { EducationCenter } from './components/Education/EducationCenter';
import { ClinicalTimeline } from './components/Timeline/ClinicalTimeline';
import { ConfigurationPanel } from './components/Configuration/ConfigurationPanel';
import { EncounterCommandStrip } from './components/Workspace/EncounterCommandStrip';
import { CPUStatusBar } from './components/Workspace/CPUStatusBar';
import { SectionNavigator } from './components/History/SectionNavigator';
import { QuestionCapture } from './components/History/QuestionCapture';
import { ChiefComplaintPanel } from './components/History/ChiefComplaintPanel';
import { EncounterList } from './components/EncounterList';
import { AdminWorkspace } from './admin';
import {
  CrossIcon,
  PlayIcon,
  GridIcon,
  ArrowLeftIcon,
  CogIcon,
} from './components/Icons';

const NAV_TO_TAB: Record<string, TabId> = {
  history: 'history',
  biodata: 'history',
  chief_complaint: 'history',
  hpi: 'history',
  past_medical_history: 'history',
  past_surgical_history: 'history',
  family_history: 'history',
  social_history: 'history',
  review_of_systems: 'history',
  obstetric_history: 'history',
  gynaecological_history: 'history',
  anc_profile: 'history',
  birth_history: 'history',
  growth_development: 'history',
  immunization: 'history',
  nutrition: 'history',
  neonatal_history: 'history',
  psychiatric_history: 'history',

  exam: 'exam',
  examination: 'exam',

  assessment: 'reasoning',
  reasoning: 'reasoning',
  clinical_reasoning: 'reasoning',

  investigations: 'investigations',

  management: 'management',
  treatment: 'management',
  protocol: 'management',

  monitoring: 'monitoring',

  documentation: 'docs',
  docs: 'docs',
};

const TAB_LABELS: Record<TabId, string> = {
  history: 'History',
  reasoning: 'Clinical Reasoning',
  exam: 'Examination',
  investigations: 'Investigations',
  management: 'Management',
  monitoring: 'Monitoring',
  docs: 'Documentation',
  education: 'Education',
  timeline: 'Timeline',
  configuration: 'Configuration',
};

const TAB_PRIORITY: Record<
  TabId,
  'routine' | 'important' | 'urgent' | 'emergency'
> = {
  history: 'routine',
  reasoning: 'important',
  exam: 'important',
  investigations: 'important',
  management: 'urgent',
  monitoring: 'emergency',
  docs: 'routine',
  education: 'routine',
  timeline: 'routine',
  configuration: 'routine',
};

const CLINICAL_TABS: TabId[] = [
  'history',
  'exam',
  'reasoning',
  'investigations',
  'management',
  'monitoring',
  'docs',
];

function mappingNavToTab(sectionCode: string): TabId | null {
  return NAV_TO_TAB[sectionCode] ?? null;
}

function deriveSectionTabs(
  _projection: EnhancedClinicalRuntimeProjection | null,
): TabId[] {
  return [...CLINICAL_TABS];
}

function sectionStateForTab(
  projection: EnhancedClinicalRuntimeProjection | null,
  tab: TabId,
): WorkspaceSectionProjection | undefined {
  if (!projection?.navigation?.sections) return undefined;

  return projection.navigation.sections.find((section) => {
    return mappingNavToTab(section.sectionCode) === tab;
  });
}

function sectionBadge(
  projection: EnhancedClinicalRuntimeProjection | null,
  tab: TabId,
): number | null {
  const section = sectionStateForTab(projection, tab);
  return section?.badge ?? null;
}

function calculateAge(
  birthDate: string,
): {
  years: number;
  months: number;
  days: number;
} {
  const birth = new Date(`${birthDate}T00:00:00`);
  const today = new Date();

  let years = today.getFullYear() - birth.getFullYear();
  let months = today.getMonth() - birth.getMonth();
  let days = today.getDate() - birth.getDate();

  if (days < 0) {
    months -= 1;

    const previousMonth = new Date(
      today.getFullYear(),
      today.getMonth(),
      0,
    );

    days += previousMonth.getDate();
  }

  if (months < 0) {
    years -= 1;
    months += 12;
  }

  return {
    years: Math.max(0, years),
    months: Math.max(0, months),
    days: Math.max(0, days),
  };
}

function mapSeverityToLevel(
  severity: string,
): AlertType['level'] {
  switch ((severity ?? '').toUpperCase()) {
    case 'CRITICAL':
      return 'emergency';
    case 'HIGH':
      return 'urgent';
    case 'MODERATE':
    case 'MEDIUM':
      return 'warning';
    default:
      return 'info';
  }
}

function deriveUIState(
  projection: EnhancedClinicalRuntimeProjection,
): ClinicalUIState {
  let activeWorkspace: TabId = 'history';

  const cpuActiveSection =
    projection.navigation?.activeSection ?? '';

  const cpuTab = mappingNavToTab(cpuActiveSection);

  if (cpuTab) {
    activeWorkspace = cpuTab;
  }

  const emergency = projection.alerts.some(
    (alert) => alert.level === 'emergency',
  );

  const urgent = projection.alerts.some(
    (alert) => alert.level === 'urgent',
  );

  if (emergency) {
    activeWorkspace = 'monitoring';
  }

  const activeSection =
    projection.navigation?.sections?.find(
      (section) =>
        section.sectionCode === cpuActiveSection,
    );

  let taskType: ClinicalUIState['task']['type'] = 'history';

  if (activeWorkspace === 'reasoning') {
    taskType = 'reasoning';
  } else if (activeWorkspace === 'exam') {
    taskType = 'examination';
  } else if (activeWorkspace === 'investigations') {
    taskType = 'investigation';
  } else if (activeWorkspace === 'management') {
    taskType = 'management';
  } else if (activeWorkspace === 'monitoring') {
    taskType = 'monitoring';
  } else if (activeWorkspace === 'docs') {
    taskType = 'documentation';
  }

  let priority:
    | 'routine'
    | 'important'
    | 'urgent'
    | 'emergency' = 'routine';

  if (emergency) {
    priority = 'emergency';
  } else if (urgent) {
    priority = 'urgent';
  } else if (
    activeWorkspace === 'reasoning' ||
    activeWorkspace === 'exam' ||
    activeWorkspace === 'investigations'
  ) {
    priority = 'important';
  }

  const criticalAlert = projection.alerts.find(
    (alert) =>
      alert.level === 'emergency' ||
      alert.level === 'urgent',
  );

  let nextAction = {
    type: 'question',
    code: '',
    label:
      activeSection?.label ??
      'Continue clinical history',
    rationale:
      activeSection?.reason ??
      'Continue according to the current CPU workflow.',
  };

  if (criticalAlert) {
    nextAction = {
      type: 'alert',
      code: criticalAlert.code,
      label: criticalAlert.message,
      rationale: 'Immediate clinical attention is required.',
    };
  } else if (projection.nextQuestions.length > 0) {
    const question = projection.nextQuestions[0];

    nextAction = {
      type: 'question',
      code: question.questionCode,
      label: question.text,
      rationale:
        question.reason ||
        'This is the next question selected by the clinical CPU.',
    };
  } else if (activeSection) {
    nextAction = {
      type: 'section',
      code: activeSection.sectionCode,
      label: activeSection.label,
      rationale:
        activeSection.reason ||
        'Continue the current clinical workflow.',
    };
  }

  const blockingIssues: string[] = [];

  if (projection.nextQuestions.some(
    (question) =>
      question.requirementLevel === 'mandatory',
  )) {
    blockingIssues.push(
      'Required clinical questions remain unanswered.',
    );
  }

  if (
    projection.alerts.some(
      (alert) => alert.level === 'emergency',
    )
  ) {
    blockingIssues.push(
      'Emergency clinical alert requires immediate attention.',
    );
  }

  if (
    projection.navigation?.sections?.some(
      (section) => section.state === 'locked',
    )
  ) {
    blockingIssues.push(
      'One or more workflow sections are currently blocked by the clinical CPU.',
    );
  }

  return {
    activeWorkspace,
    task: {
      type: taskType,
      code: cpuActiveSection || 'history',
      priority,
    },
    nextAction,
    blockingIssues,
    alerts: projection.alerts,
    confidence:
      projection.confidence?.leadingPhenotypeScore ?? 0,
  };
}

type ViewState = 'entry' | 'records' | 'workspace' | 'admin';

interface EncounterContextState {
  patientId: string;
  encounterId: string | null;
  sex: 'male' | 'female' | 'intersex' | 'unknown';
  ageYears: number | null;
  ageMonths: number | null;
  ageDays: number | null;
  pregnancyState:
    | 'not_applicable'
    | 'not_pregnant'
    | 'pregnant'
    | 'postpartum'
    | 'unknown';
  requestedDepartment:
    | 'medical'
    | 'surgical'
    | 'obgyn'
    | 'paediatrics'
    | 'neonatology'
    | 'psychiatry'
    | 'emergency'
    | 'other';
  encounterType: string | null;
  presentingComplaintCodes: string[];
  activeSymptomCodes: string[];
  firstVisit: boolean;
  emergency: boolean;
}

export default function App() {
  const [projection, setProjection] =
    useState<EnhancedClinicalRuntimeProjection | null>(null);

  const [uiState, setUiState] =
    useState<ClinicalUIState | null>(null);

  const [timeline, setTimeline] =
    useState<TimelineEvent[]>([]);

  const [demo, setDemo] =
    useState<{
      patientId: string;
      encounterId: string;
    } | null>(null);

  const [tab, setTab] =
    useState<TabId>('history');

  const [connection, setConnection] =
    useState<ConnectionState>('offline');

  const [starting, setStarting] =
    useState(false);

  const [error, setError] =
    useState<string | null>(null);

  const [view, setView] =
    useState<ViewState>('entry');

  const [universalProjection, setUniversalProjection] =
    useState<UniversalClinicalProjection | null>(null);

  const [safetyAlerts, setSafetyAlerts] =
    useState<SafetyAlert[]>([]);

  const [universalFacts, setUniversalFacts] =
    useState<ClinicalFact[]>([]);

  const [examValues, setExamValues] =
    useState<Record<string, unknown>>({});

  // Archive of every question ever projected, so answered questions remain
  // visible and editable even after the CPU stops re-asking them.
  const [questionArchive, setQuestionArchive] =
    useState<Record<string, CaptureQuestion>>({});

  const [activeSection, setActiveSection] =
    useState<string>('biodata');

  const [docMinimized, setDocMinimized] =
    useState(false);

  const [sideMinimized, setSideMinimized] =
    useState(false);

  const [encounterContext, setEncounterContext] =
    useState<EncounterContextState | null>(null);

  const refreshTimeline = useCallback(
    async (patientId: string) => {
      try {
        const entries = await getTimeline(patientId);
        setTimeline(entries);
      } catch {
        setTimeline([]);
      }
    },
    [],
  );

  useEffect(() => {
    if (!projection) {
      setUiState(null);
      return;
    }

    setUiState(deriveUIState(projection));
  }, [projection]);

  useEffect(() => {
    if (!projection || !uiState) return;

    const activeCPUSection =
      projection.navigation?.activeSection;

    const cpuTab = activeCPUSection
      ? mappingNavToTab(activeCPUSection)
      : null;

    if (
      uiState.task.priority === 'emergency' &&
      cpuTab !== 'history' &&
      tab !== 'history'
    ) {
      setTab('monitoring');
    }
  }, [projection, uiState, tab]);

  useEffect(() => {
    if (!demo) return;

    let closed = false;

    setConnection('syncing');

    const unsubscribe = subscribeProjection(
      demo.patientId,
      demo.encounterId ?? null,
      (nextProjection: EnhancedClinicalRuntimeProjection) => {
        if (closed) return;

        setProjection(nextProjection);

        setConnection('online');
      },
      () => {
        if (closed) return;
        setConnection('offline');
      },
    );

    void refreshTimeline(demo.patientId);

    return () => {
      closed = true;
      unsubscribe.close();
    };
  }, [demo, refreshTimeline]);

  // AMEXAN Safety Sentinel — fetch and keep the open safety alerts for the
  // active encounter so the clinician sees dose/protocol alerts immediately.
  useEffect(() => {
    if (!demo?.encounterId) {
      setSafetyAlerts([]);
      return;
    }

    let cancelled = false;

    const load = async () => {
      try {
        const alerts = await listEncounterAlerts(
          demo.encounterId as string,
        );
        if (!cancelled) setSafetyAlerts(alerts);
      } catch {
        if (!cancelled) setSafetyAlerts([]);
      }
    };

    void load();

    const interval = window.setInterval(load, 15000);

    return () => {
      cancelled = true;
      window.clearInterval(interval);
    };
  }, [demo?.encounterId]);

  useEffect(() => {
    if (!encounterContext) {
      setUniversalProjection(null);
      return;
    }

    const built = buildProjection({
      patientId: encounterContext.patientId,
      encounterId: encounterContext.encounterId,
      ageYears: encounterContext.ageYears,
      ageMonths: encounterContext.ageMonths,
      ageDays: encounterContext.ageDays,
      sex: encounterContext.sex,
      pregnancyState: encounterContext.pregnancyState,
      requestedDepartment: encounterContext.requestedDepartment,
      encounterType: encounterContext.encounterType,
      presentingComplaintCodes:
        encounterContext.presentingComplaintCodes,
      activeSymptomCodes: encounterContext.activeSymptomCodes,
      firstVisit: encounterContext.firstVisit,
      emergency: encounterContext.emergency,
      facts: universalFacts,
      activeSection,
      eventId: universalFacts.length,
    });

    // Merge the CPU's resolved next questions (PostgreSQL knowledge graph â€”
    // biodata, adaptive pregnancy/weight rules) into the universal question
    // stack so the workspace renders exactly what the CPU decides.
    const cpuNext =
      (projection as EnhancedClinicalRuntimeProjection | null)
        ?.nextQuestions ?? [];

    // Surface AMEXAN Safety Sentinel alerts (dose/protocol) alongside the
    // CPU's own clinical alerts so the workspace shows the complete picture.
    const sentinelAlerts: AlertType[] = safetyAlerts.map((alert) => ({
      level: mapSeverityToLevel(alert.severity),
      code: alert.code,
      message: alert.message,
    }));

    setUniversalProjection(
      cpuNext.length > 0
        ? {
            ...built,
            questions: mergeCpuQuestions(
              built.questions,
              cpuNext,
            ),
            alerts: [
              ...(built.alerts ?? []),
              ...sentinelAlerts,
            ],
          }
        : {
            ...built,
            alerts: [
              ...(built.alerts ?? []),
              ...sentinelAlerts,
            ],
          },
    );
  }, [universalFacts, activeSection, encounterContext, projection, safetyAlerts]);

  // Persist every question ever resolved so answered cards never disappear.
  useEffect(() => {
    if (!universalProjection) return;

    setQuestionArchive((previous) => {
      const next = { ...previous };
      for (const question of universalProjection.questions) {
        next[question.questionCode] = question;
      }
      return next;
    });
  }, [universalProjection]);

  const handleStart = useCallback(
    async () => {
      setStarting(true);
      setError(null);

      try {
        // No intake form: the encounter starts with zero patient context and
        // the biodata section (PostgreSQL questions) collects name, sex, age,
        // DOB, occupation, residence, informant and next of kin adaptively.
        const result = await startEncounter({
          patientId: crypto.randomUUID(),
          encounterTypeCode: 'inpatient',
        });

        const nextProjection =
          result.projection as unknown as EnhancedClinicalRuntimeProjection;

        setProjection(nextProjection);

        const patientId = nextProjection.patientId;
        const encounterId = nextProjection.encounterId ?? '';

        setDemo({ patientId, encounterId });

        setEncounterContext({
          patientId,
          encounterId,
          sex: 'unknown',
          ageYears: null,
          ageMonths: null,
          ageDays: null,
          pregnancyState: 'not_applicable',
          requestedDepartment: 'other',
          encounterType: 'inpatient',
          presentingComplaintCodes: [],
          activeSymptomCodes: [],
          firstVisit: true,
          emergency: false,
        });

        setUniversalFacts([]);
        setActiveSection('biodata');
        setView('workspace');

        setConnection('syncing');

        await refreshTimeline(patientId);
      } catch (e) {
        setError(
          e instanceof Error
            ? e.message
            : 'Failed to start clinical encounter.',
        );
      } finally {
        setStarting(false);
      }
    },
    [refreshTimeline],
  );

  const handleOpenEncounter = useCallback(
    async (encounter: EncounterSummary) => {
      setError(null);

      try {
        const snapshot = await getEncounterSnapshot(
          encounter.encounterId,
        );

        const facts: ClinicalFact[] = snapshot.facts.map(
          (fact) => ({
            id: fact.id,
            patientId: snapshot.patientId,
            encounterId: snapshot.encounterId,
            factCode: fact.factCode,
            section: fact.section as ClinicalFact['section'],
            value: {
              text: fact.text,
              code: fact.text,
              numeric: fact.numeric,
              boolean: fact.boolean,
              unitCode: fact.unitCode,
            },
            sourceType: 'patient_history',
            recordedAt: fact.recordedAt,
          }),
        );

        const age = snapshot.context.birthDate
          ? calculateAge(snapshot.context.birthDate)
          : null;

        const complaintCodes = snapshot.context.presentingComplaint
          ? [
              snapshot.context.presentingComplaint
                .toUpperCase()
                .replace(/\s+/g, '_'),
            ]
          : [];

        setDemo({
          patientId: snapshot.patientId,
          encounterId: snapshot.encounterId,
        });

        setEncounterContext({
          patientId: snapshot.patientId,
          encounterId: snapshot.encounterId,
          sex: (snapshot.context.sex as
            | 'male'
            | 'female'
            | 'intersex'
            | 'unknown') ?? 'unknown',
          ageYears: age?.years ?? null,
          ageMonths: age?.months ?? null,
          ageDays: age?.days ?? null,
          pregnancyState: 'unknown',
          requestedDepartment: 'medical',
          encounterType: snapshot.context.encounterTypeCode,
          presentingComplaintCodes: complaintCodes,
          activeSymptomCodes: complaintCodes,
          firstVisit: false,
          emergency: false,
        });

        setUniversalFacts(facts);
        setActiveSection('biodata');
        setView('workspace');
      } catch (e) {
        setError(
          e instanceof Error
            ? e.message
            : 'Failed to open clinical encounter.',
        );
      }
    },
    [],
  );

  const handleEvent = useCallback(
    async (clinicalEvent: ClinicalEvent) => {
      if (!demo) return;

      setConnection('syncing');
      setError(null);

      try {
        const next = await sendEvent(
          demo.patientId,
          demo.encounterId || null,
          clinicalEvent,
        );

        setProjection(
          next as EnhancedClinicalRuntimeProjection,
        );

        await refreshTimeline(
          demo.patientId,
        );

        setConnection('online');
      } catch (e) {
        setError(
          e instanceof Error
            ? e.message
            : 'Clinical event failed.',
        );

        setConnection('offline');
      }
    },
    [demo, refreshTimeline],
  );

  const handleHistoryEvent = useCallback(
    (clinicalEvent: any) => {
      const type = clinicalEvent?.type;
      const payload = clinicalEvent?.payload ?? {};

      if (type === 'HISTORY_SECTION_CHANGED') {
        if (typeof payload.section === 'string') {
          setActiveSection(payload.section);
        }
        return;
      }

      if (type === 'QUESTION_ANSWERED') {
        if (universalProjection && demo) {
          const newFacts = factsFromAnswer(
            clinicalEvent,
            universalProjection,
            demo.patientId,
            demo.encounterId,
          );

          if (newFacts.length > 0) {
            setUniversalFacts((previous) => {
              const replacedCodes = new Set(
                newFacts
                  .map((fact) => fact.factCode)
                  .filter((code): code is string => Boolean(code)),
              );

              const retained = previous.filter(
                (fact) =>
                  !replacedCodes.has(fact.factCode),
              );

              return [...retained, ...newFacts];
            });
          }
        }

        void handleEvent(clinicalEvent);
        return;
      }

      if (type === 'CHIEF_COMPLAINTS_SAVED') {
        if (demo) {
          const complaints = (
            payload.complaints as ChiefComplaintInput[] | undefined
          ) ?? [];

          const complaintFacts = complaintFactsFromSave(
            complaints,
            demo.patientId,
            demo.encounterId,
            'chief_complaint',
          );

          setUniversalFacts((previous) => [
            ...previous.filter(
              (fact) =>
                !isComplaintFactCode(fact.factCode),
            ),
            ...complaintFacts,
          ]);

          setEncounterContext((previous) => {
            if (!previous) return previous;

            return {
              ...previous,
              presentingComplaintCodes: complaints.map(
                (item) => item.code,
              ),
              activeSymptomCodes: complaints.map(
                (item) => item.code,
              ),
            };
          });
        }

        void handleEvent(clinicalEvent);
        return;
      }

      void handleEvent(clinicalEvent);
    },
    [universalProjection, demo, handleEvent],
  );

  const handleExamCapture = useCallback(
    (
      findingCode: string,
      value: unknown,
      unit?: string | null,
    ) => {
      setExamValues((previous) => ({
        ...previous,
        [findingCode]: value,
      }));

      if (!demo) return;

      void handleEvent(
        examFindingCaptured(findingCode, value, unit),
      );
    },
    [demo, handleEvent],
  );

  const sectionTabs = useMemo(
    () => deriveSectionTabs(projection),
    [projection],
  );

  const universalSections =
    universalProjection?.sections ?? [];
  const universalQuestions =
    universalProjection?.questions ?? [];
  const universalFactsList =
    universalProjection?.capturedFacts ?? [];

  const activeIndex = Math.max(
    0,
    universalSections.findIndex(
      (section) => section.code === activeSection,
    ),
  );

  const activeSectionDef: HistorySectionDefinition | undefined =
    universalSections[activeIndex] ??
    universalSections.find(
      (section) => section.code === activeSection,
    ) ??
    universalSections[0];

  const activeCode = activeSectionDef?.code ?? 'biodata';

  const activeQuestions = universalQuestions.filter(
    (question) => question.section === activeCode,
  );

  const activeFacts = universalFactsList.filter(
    (fact) => fact.section === activeCode,
  );

  const mandatoryRemaining = activeQuestions.filter(
    (question) => question.requirementLevel === 'mandatory',
  ).length;

  const goToSection = useCallback(
    (sectionCode: string) => {
      const target = universalSections.find(
        (section) => section.code === sectionCode,
      );

      if (!target) return;

      setActiveSection(target.code);
    },
    [universalSections],
  );

  const nextSection =
    universalSections[activeIndex + 1];
  const previousSection =
    universalSections[activeIndex - 1];

  return (
    <div className="workspace">
      <WorkspaceHeader
        connection={connection}
        patientId={demo?.patientId ?? null}
        encounterId={demo?.encounterId ?? null}
        alertCount={
          projection?.alerts?.filter(
            (alert) =>
              alert.level === 'emergency' ||
              alert.level === 'urgent',
          ).length ?? 0
        }
        formatPlan={projection?.formatPlan}
      />

      {error && (
        <div
          className="banner banner-error"
          role="alert"
        >
          {error}
        </div>
      )}

      {view === 'admin' && (
        <AdminWorkspace onExit={() => setView('entry')} />
      )}

      {view === 'entry' && (
        <EntryPage
          starting={starting}
          onRecords={() => setView('records')}
          onStart={() => void handleStart()}
          onAdmin={() => setView('admin')}
        />
      )}

      {view === 'records' && (
        <RecordsScreen
          onBack={() => {
            setView('entry');
          }}
          onNewEncounter={() => {
            setView('entry');
          }}
          onOpenEncounter={(encounter) => {
            void handleOpenEncounter(encounter);
          }}
        />
      )}

      {view === 'workspace' &&
        (!projection || !demo || !universalProjection ? (
          <div className="loading-state" aria-live="polite">
            <div className="loading-spinner" aria-hidden="true" />
            <span>Preparing clinical workspaceâ€¦</span>
          </div>
        ) : (
          <>
            <div className="phase-tabs-row">
              <nav
                className="tabs"
                aria-label="Clinical workspace"
              >
                {sectionTabs.map((tabId) => {
                  const section =
                    sectionStateForTab(
                      projection,
                      tabId,
                    );

                  const isActive =
                    tab === tabId;

                  const isLocked =
                    section?.state ===
                      'locked';

                  const badge =
                    sectionBadge(
                      projection,
                      tabId,
                    );

                  const contentCount =
                    getTabContentCount(
                      projection,
                      tabId,
                    );

                  const priority =
                    TAB_PRIORITY[tabId];

                  return (
                    <button
                      key={tabId}
                      type="button"
                      className={[
                        'tab',
                        isActive
                          ? 'active'
                          : '',
                        priority === 'urgent' &&
                        uiState?.task.priority ===
                          'urgent'
                          ? 'tab-urgent'
                          : '',
                        priority === 'emergency' &&
                        uiState?.task.priority ===
                          'emergency'
                          ? 'tab-emergency'
                          : '',
                        contentCount > 0
                          ? 'tab-has-content'
                          : '',
                        isLocked
                          ? 'tab-locked'
                          : '',
                      ]
                        .filter(Boolean)
                        .join(' ')}
                      disabled={isLocked}
                      title={
                        isLocked
                          ? section?.reason ??
                            'Section currently unavailable.'
                          : undefined
                      }
                      onClick={() =>
                        setTab(tabId)
                      }
                    >
                      <span>
                        {section?.label ??
                          TAB_LABELS[tabId]}
                      </span>

                      {badge != null &&
                        badge > 0 && (
                          <span className="tab-badge">
                            {badge}
                          </span>
                        )}
                    </button>
                  );
                })}
              </nav>
            </div>

            <div className="workspace-grid">
              <aside className="ws-nav">
                {tab === 'exam' && (
                  <div className="exam-return">
                    <button
                      type="button"
                      className="exam-return-btn"
                      onClick={() => setTab('history')}
                    >
                      <span aria-hidden="true">←</span>
                      <span>
                        <strong>Back to History</strong>
                        <small>Review captured questions</small>
                      </span>
                    </button>
                  </div>
                )}
                {tab !== 'exam' && (
                  <SectionNavigator
                    sections={universalSections}
                    activeSection={activeCode}
                    onSectionChange={goToSection}
                    sectionFacts={sectionMap(universalFactsList)}
                    sectionQuestions={sectionMap(universalQuestions)}
                    onNavigateToExam={() => setTab('exam')}
                  />
                )}

                <div className="nav-footer">
                  <button
                    type="button"
                    className="history-navigation-btn previous"
                    disabled={!previousSection}
                    onClick={() =>
                      previousSection &&
                      goToSection(
                        previousSection.code,
                      )
                    }
                  >
                    {previousSection
                      ? `Previous: ${
                          previousSection.label
                        }`
                      : 'Previous'}
                  </button>

                  <div className="nav-section-status">
                    {activeFacts.length > 0 ? (
                      <span className="section-complete">
                        Section captured
                      </span>
                    ) : (
                      <span className="section-incomplete">
                        Section awaiting capture
                      </span>
                    )}

                    {mandatoryRemaining > 0 && (
                      <span className="section-mandatory-count">
                        {mandatoryRemaining} mandatory
                        question
                        {mandatoryRemaining !== 1
                          ? 's'
                          : ''}{' '}
                        remaining
                      </span>
                    )}
                  </div>

                  <button
                    type="button"
                    className="history-navigation-btn next"
                    disabled={!nextSection}
                    onClick={() =>
                      nextSection &&
                      goToSection(
                        nextSection.code,
                      )
                    }
                  >
                    {nextSection
                      ? `Next: ${nextSection.label}`
                      : 'Finish'}
                  </button>

                  <button
                    type="button"
                    className="history-navigation-btn exam"
                    onClick={() => setTab('exam')}
                  >
                    🩺 Continue to Examination →
                  </button>
                </div>
              </aside>

              <section className="ws-main">
                <main className="main">
                  {tab === 'history' && (
                    <div className="history-window">
                      {activeSectionDef && (
                        <header className="section-header history-section-heading">
                        <div className="section-title-group">
                          <div>
                            <span className="section-sequence">
                              {activeSectionDef.sequence}
                            </span>

                            <h2 className="section-title">
                              {activeSectionDef.label}
                            </h2>
                          </div>

                          {activeSectionDef.required && (
                            <span className="required-pill">
                              Required
                            </span>
                          )}
                        </div>

                        <div className="section-meta">
                          <span className="fact-count">
                            {activeFacts.length}{' '}
                            {activeFacts.length === 1
                              ? 'fact'
                              : 'facts'}
                          </span>

                          {mandatoryRemaining > 0 && (
                            <span className="mandatory-remaining">
                              {mandatoryRemaining}{' '}
                              mandatory remaining
                            </span>
                          )}
                        </div>
                      </header>
                    )}

                    {activeCode === 'chief_complaint' ? (
                      <ChiefComplaintPanel
                        facts={activeFacts}
                        onSave={(complaints) => {
                          handleHistoryEvent({
                            type: 'CHIEF_COMPLAINTS_SAVED',
                            payload: {
                              patientId:
                                encounterContext?.patientId ?? '',
                              encounterId:
                                encounterContext?.encounterId ?? null,
                              section: 'chief_complaint',
                              complaints,
                            },
                          });
                        }}
                        onContinue={() => {
                          if (nextSection) {
                            goToSection(nextSection.code);
                          }
                        }}
                      />
                    ) : (
                      <QuestionCapture
                        questions={activeQuestions}
                        archivedQuestions={Object.values(
                          questionArchive,
                        )}
                        facts={activeFacts}
                        section={activeCode}
                        patientId={encounterContext?.patientId ?? ''}
                        encounterId={encounterContext?.encounterId ?? null}
                        onEvent={handleHistoryEvent}
                      />
                    )}
                  </div>
                )}

                {tab === 'reasoning' && (
                  <ReasoningDrawer
                    projection={projection}
                    uiState={uiState}
                    onClose={() =>
                      setTab('history')
                    }
                  />
                )}

                {tab === 'exam' && (
                  <ExamWorkspace
                    context={universalProjection.context}
                    capturedValues={examValues}
                    onCapture={handleExamCapture}
                  />
                )}

                {tab === 'investigations' && (
                  <InvestigationCenter
                    projection={projection}
                    uiState={uiState}
                    onDecision={(decision) => {
                      void handleEvent(
                        clinicianDecision(
                          decision,
                        ),
                      );
                    }}
                    onResult={(result) => {
                      void handleEvent(
                        result.event,
                      );
                    }}
                  />
                )}

                {tab === 'management' && (
                  <ManagementCenter
                    projection={projection}
                  />
                )}

                {tab === 'monitoring' && (
                  <MonitoringCenter
                    projection={projection}
                  />
                )}

                {tab === 'docs' && (
                  <DocumentationCenter
                    sections={
                      universalProjection.documentation
                    }
                    projection={projection}
                  />
                )}

                {tab === 'education' && (
                  <EducationCenter
                    education={
                      projection.education
                    }
                    uiState={uiState}
                  />
                )}

                {tab === 'timeline' && (
                  <ClinicalTimeline
                    entries={timeline}
                    projection={projection}
                  />
                )}

                {tab === 'configuration' && (
                  <ConfigurationPanel
                    projection={projection}
                  />
                )}
              </main>
            </section>

            <aside className="ws-right">
              <div className="ws-panel ws-doc">
                <div className="ws-panel-head">
                  <span className="ws-panel-title">
                    Live Documentation
                  </span>

                  <button
                    type="button"
                    className="ws-panel-toggle"
                    onClick={() =>
                      setDocMinimized((value) => !value)
                    }
                    title={
                      docMinimized
                        ? 'Show documentation'
                        : 'Hide documentation'
                    }
                    aria-label={
                      docMinimized
                        ? 'Show documentation'
                        : 'Hide documentation'
                    }
                  >
                    {docMinimized ? '»' : '«'}
                  </button>
                </div>

                {docMinimized ? (
                  <button
                    type="button"
                    className="ws-panel-rail"
                    onClick={() => setDocMinimized(false)}
                    title="Show Live Documentation"
                  >
                    <span className="ws-panel-rail-label">
                      Live Documentation
                    </span>
                  </button>
                ) : (
                  <div className="ws-panel-body">
                    <DocumentationCenter
                      sections={
                        universalProjection.documentation
                      }
                      projection={projection}
                    />
                  </div>
                )}
              </div>

              <div className="ws-panel ws-facts">
                <div className="ws-panel-head">
                  <span className="ws-panel-title">
                    Captured Facts
                  </span>

                  <span className="ws-panel-count">
                    {universalFactsList.length}
                  </span>
                </div>

                <div className="ws-panel-body">
                  <FactsPanel facts={universalFactsList} />
                </div>
              </div>

              <div className="ws-panel ws-side">
                <div className="ws-panel-head">
                  <span className="ws-panel-title">
                    Patient & State
                  </span>

                  <button
                    type="button"
                    className="ws-panel-toggle"
                    onClick={() =>
                      setSideMinimized((value) => !value)
                    }
                    title={
                      sideMinimized
                        ? 'Show patient panel'
                        : 'Hide patient panel'
                    }
                    aria-label={
                      sideMinimized
                        ? 'Show patient panel'
                        : 'Hide patient panel'
                    }
                  >
                    {sideMinimized ? '»' : '«'}
                  </button>
                </div>

                {sideMinimized ? (
                  <button
                    type="button"
                    className="ws-panel-rail"
                    onClick={() => setSideMinimized(false)}
                    title="Show Patient & State"
                  >
                    <span className="ws-panel-rail-label">
                      Patient & State
                    </span>
                  </button>
                ) : (
                  <div className="ws-panel-body">
                    <PatientSnapshot
                      projection={projection}
                      uiState={uiState}
                    />

                    <EncounterCommandStrip
                      projection={projection}
                    />

                    <CPUStatusBar
                      uiState={uiState}
                      projection={projection}
                    />

                    <AlertsBanner
                      alerts={universalProjection.alerts}
                    />
                  </div>
                )}
              </div>
            </aside>
          </div>
          </>
        ))}
    </div>
  );
}

function getTabContentCount(
  projection: EnhancedClinicalRuntimeProjection,
  tabId: TabId,
): number {
  const section =
    sectionStateForTab(
      projection,
      tabId,
    );

  if (section) {
    return (
      section.badge ??
      section.requiredRemaining ??
      0
    );
  }

  switch (tabId) {
    case 'history':
      return (
        projection.capturedFacts
          ?.length ?? 0
      );

    case 'reasoning':
      return (
        projection.differentials
          ?.length ?? 0
      );

    case 'exam':
      return (
        projection.examination
          ?.length ?? 0
      );

    case 'investigations':
      return (
        projection.investigations
          ?.length ?? 0
      );

    case 'management':
      return projection.protocol ? 1 : 0;

    case 'monitoring':
      return (
        projection.monitoring
          ?.length ?? 0
      );

    case 'docs':
      return (
        projection.documentation
          ?.length ?? 0
      );

    case 'education':
      return (
        projection.education
          ?.length ?? 0
      );

    default:
      return 0;
  }
}

function sectionMap<T extends { section: string }>(
  items: T[],
): Map<string, T[]> {
  const map = new Map<string, T[]>();

  for (const item of items) {
    const list = map.get(item.section) ?? [];
    list.push(item);
    map.set(item.section, list);
  }

  return map;
}

function factsFromAnswer(
  clinicalEvent: any,
  projection: UniversalClinicalProjection,
  patientId: string,
  encounterId: string,
): ClinicalFact[] {
  const payload = clinicalEvent?.payload ?? {};

  const question = projection.questions.find(
    (candidate) =>
      candidate.questionCode === payload.questionCode,
  );

  const factCode =
    typeof payload.factCode === 'string' && payload.factCode
      ? (payload.factCode as string)
      : question?.factCode ?? null;

  if (!factCode) return [];

  const section =
    typeof payload.section === 'string' && payload.section
      ? (payload.section as string)
      : question?.section ?? 'hpi';

  const codes: string[] = Array.isArray(payload.answerCodes)
    ? (payload.answerCodes as string[]).filter(Boolean)
    : [];

  const rawValue = payload.rawValue;
  const unitCode =
    typeof payload.unitCode === 'string' && payload.unitCode
      ? (payload.unitCode as string)
      : question?.unitCode ?? null;

  let text: string | null = null;
  let numeric: number | null = null;
  let boolean: boolean | null = null;

  if (Array.isArray(rawValue)) {
    text = (rawValue as string[]).join(', ');
  } else if (typeof rawValue === 'number') {
    numeric = rawValue;
    text = String(rawValue);
  } else if (typeof rawValue === 'boolean') {
    boolean = rawValue;
    text = rawValue ? 'YES' : 'NO';
  } else if (typeof rawValue === 'string' && rawValue.trim() !== '') {
    text = rawValue;
  } else if (codes.length > 0) {
    text = codes.join(', ');
  }

  if (text === null && numeric === null && boolean === null) {
    return [];
  }

  return [
    {
      id: crypto.randomUUID(),
      patientId,
      encounterId,
      factCode,
      section: section as ClinicalFact['section'],
      value: {
        text,
        code: codes[0] ?? null,
        numeric,
        boolean,
        unitCode,
      },
      sourceType: 'clinician',
      recordedAt: new Date().toISOString(),
    },
  ];
}

type CpuNextQuestion =
  EnhancedClinicalRuntimeProjection['nextQuestions'][number];

// Merge the CPU's knowledge-graph questions into the universal question stack.
// Local universal questions win on code collisions; CPU-only questions are
// appended and mapped into their home section.
function mergeCpuQuestions(
  localQuestions: CaptureQuestion[],
  cpuNext: CpuNextQuestion[],
): CaptureQuestion[] {
  const localCodes = new Set(
    localQuestions.map((question) => question.questionCode),
  );

  const merged: CaptureQuestion[] = [...localQuestions];

  for (const next of cpuNext) {
    if (localCodes.has(next.questionCode)) continue;

    const section = cpuQuestionSection(
      next.questionCode,
      next.factCode,
    );

    if (!section) continue;

    merged.push(
      cpuNextToCaptureQuestion(next, section),
    );
    localCodes.add(next.questionCode);
  }

  return merged;
}

function cpuQuestionSection(
  questionCode: string,
  factCode: string | null,
): CaptureQuestion['section'] | null {
  if (questionCode.startsWith('BIODATA_')) {
    return 'biodata';
  }

  switch (factCode) {
    case 'PRESENTING_COMPLAINT':
      return 'chief_complaint';
    case 'BODY_WEIGHT_KG':
    case 'DATE_OF_BIRTH':
    case 'AGE_YEARS':
    case 'AGE_MONTHS':
    case 'AGE_DAYS':
      return 'biodata';
    case 'LMP_DATE':
    case 'EDD':
    case 'GESTATIONAL_AGE_WEEKS':
      return 'obstetric_history';
    default:
      return 'hpi';
  }
}

function cpuNextToCaptureQuestion(
  next: CpuNextQuestion,
  section: CaptureQuestion['section'],
): CaptureQuestion {
  return {
    questionCode: next.questionCode,
    section,
    subsectionCode: null,
    text: next.text,
    responseType: cpuToCaptureType(next.responseType),
    requirementLevel: cpuToRequirementLevel(
      next.requirementLevel,
    ),
    priority: 1_000_000 - next.priority,
    priorityClass: undefined,
    reason: next.reason ?? null,
    reasoning: next.reasoning ?? null,
    factCode: next.factCode ?? null,
    unitCode: next.unitCode ?? null,
    options: (next.options ?? []).map((option) => ({
      answerCode: option.answerCode,
      label: option.label,
      description: option.description ?? null,
    })),
    visible: true,
    enabled: true,
    allowUnknown: next.allowUnknown ?? false,
    allowNotApplicable: next.allowNotApplicable ?? false,
    allowDefer: next.allowDefer ?? false,
    defaultAnswer: next.defaultValue ?? null,
    source: next.source ?? null,
    validation: next.validation ?? null,
    placeholder: next.placeholder ?? null,
  };
}

function cpuToCaptureType(
  responseType: CpuNextQuestion['responseType'],
): CaptureQuestion['responseType'] {
  switch (responseType) {
    case 'single_choice':
      return 'single_select';
    case 'multi_choice':
      return 'multi_select';
    case 'coded':
      return 'coded';
    case 'measurement':
      return 'measurement';
    case 'range':
      return 'range';
    case 'long_text':
      return 'long_text';
    case 'date':
      return 'date';
    case 'datetime':
      return 'datetime';
    case 'duration':
      return 'duration';
    case 'boolean':
      return 'boolean';
    case 'numeric':
      return 'numeric';
    default:
      return 'text';
  }
}

function cpuToRequirementLevel(
  requirementLevel: CpuNextQuestion['requirementLevel'],
): CaptureQuestion['requirementLevel'] {
  switch (requirementLevel) {
    case 'mandatory':
      return 'mandatory';
    case 'conditionally_required':
      return 'conditional';
    case 'recommended':
      return 'recommended';
    case 'optional':
    default:
      return 'optional';
  }
}

function EntryPage({
  starting,
  onRecords,
  onStart,
  onAdmin,
}: {
  starting: boolean;
  onRecords: () => void;
  onStart: () => void;
  onAdmin: () => void;
}) {
  return (
    <div className="entry-page">
      <div className="entry-hero">
        <div className="entry-brand">
          <span className="brand-mark" aria-hidden="true">
            <CrossIcon size={26} />
          </span>

          <div>
            <h1>AMEXAN</h1>
            <p className="subtitle">
              Clinical Operating System
            </p>
          </div>
        </div>

        <h2 className="entry-headline">
          Universal Clinical Workspace
        </h2>

        <p className="entry-subheadline">
          Capture complete clinical histories, run structured reasoning and
          document every consultation â€” from any department.
        </p>

        <div className="entry-ctas">
          <button
            type="button"
            className="entry-cta primary"
            disabled={starting}
            onClick={onStart}
          >
            <span className="cta-icon" aria-hidden="true">
              <PlayIcon size={20} />
            </span>

            <span className="cta-text">
              <strong>Start Encounter</strong>
              <small>
                Begin a new patient consultation â€” patient details are captured
                in the biodata section
              </small>
            </span>
          </button>

          <button
            type="button"
            className="entry-cta"
            onClick={onRecords}
          >
            <span className="cta-icon" aria-hidden="true">
              <GridIcon size={20} />
            </span>

            <span className="cta-text">
              <strong>Records of Histories Done</strong>
              <small>
                Review previously completed encounters
              </small>
            </span>
          </button>

          <button
            type="button"
            className="entry-cta"
            onClick={onAdmin}
          >
            <span className="cta-icon" aria-hidden="true">
              <CogIcon size={20} />
            </span>

            <span className="cta-text">
              <strong>AMEXAN Control Plane</strong>
              <small>
                Command Center, events, engines, safety, configuration and RBAC
              </small>
            </span>
          </button>
        </div>
      </div>
    </div>
  );
}

function RecordsScreen({
  onBack,
  onNewEncounter,
  onOpenEncounter,
}: {
  onBack: () => void;
  onNewEncounter: (symptom: string) => void;
  onOpenEncounter: (encounter: EncounterSummary) => void;
}) {
  return (
    <div className="records-screen">
      <div className="records-toolbar">
        <button
          type="button"
          className="back-btn"
          onClick={onBack}
        >
          <ArrowLeftIcon size={16} />
          Back
        </button>

        <span className="muted small">
          Records of Histories Done
        </span>
      </div>

      <EncounterList
        onNewEncounter={async (symptom: string) => {
          onNewEncounter(symptom);
        }}
        onOpenEncounter={onOpenEncounter}
      />
    </div>
  );
}

