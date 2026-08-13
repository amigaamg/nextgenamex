import { useCallback, useEffect, useState } from 'react';
import { getTimeline, sendEvent, startDemo, subscribeProjection, questionAnswered, questionSkipped, examFindingCaptured, clinicianDecision } from './api';
import type {
  ClinicalEvent,
  ClinicalRuntimeProjection,
  ConnectionState,
  TabId,
  TimelineEvent,
} from './types';
import { WorkspaceHeader } from './components/WorkspaceHeader';
import { EncounterPhaseBar, PHASES } from './components/EncounterPhaseBar';
import { PatientSnapshot } from './components/Workspace/PatientSnapshot';
import { AlertsBanner } from './components/Alerts/AlertsBanner';
import { QuestionCard } from './components/Capture/QuestionCard';
import { FactChips } from './components/Capture/FactChips';
import { ReasoningDrawer } from './components/Reasoning/ReasoningDrawer';
import { ExaminationPanel } from './components/Examination/ExaminationPanel';
import { InvestigationCenter } from './components/Investigations/InvestigationCenter';
import { ManagementCenter } from './components/Management/ManagementCenter';
import { MonitoringCenter } from './components/Monitoring/MonitoringCenter';
import { DocumentationCenter } from './components/Documentation/DocumentationCenter';
import { EducationCenter } from './components/Education/EducationCenter';
import { ClinicalTimeline } from './components/Timeline/ClinicalTimeline';
import { ConfigurationPanel } from './components/Configuration/ConfigurationPanel';

const TABS: { id: TabId; label: string }[] = [
  { id: 'history', label: 'History' },
  { id: 'reasoning', label: 'Reasoning' },
  { id: 'exam', label: 'Exam' },
  { id: 'investigations', label: 'Investigations' },
  { id: 'management', label: 'Management' },
  { id: 'monitoring', label: 'Monitoring' },
  { id: 'docs', label: 'Documentation' },
  { id: 'education', label: 'Education' },
  { id: 'timeline', label: 'Timeline' },
  { id: 'configuration', label: 'Configuration' },
];

export default function App() {
  const [projection, setProjection] = useState<ClinicalRuntimeProjection | null>(null);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [demo, setDemo] = useState<{ patientId: string; encounterId: string } | null>(null);
  const [tab, setTab] = useState<TabId>('history');
  const [connection, setConnection] = useState<ConnectionState>('offline');
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refreshTimeline = useCallback(async (patientId: string) => {
    try {
      setTimeline(await getTimeline(patientId));
    } catch {
      setTimeline([]);
    }
  }, []);

  useEffect(() => {
    if (!demo) return;
    let closed = false;
    const unsubscribe = subscribeProjection(
      demo.patientId,
      (p) => {
        if (!closed) setProjection(p);
      },
      () => {
        if (!closed) setConnection('offline');
      },
    );
    setConnection('online');
    return () => {
      closed = true;
      unsubscribe();
    };
  }, [demo, refreshTimeline]);

  const handleDemo = useCallback(
    async (symptom: string) => {
      setStarting(true);
      setError(null);
      try {
        const result = await startDemo(symptom);
        setProjection(result.projection);
        setDemo({ patientId: result.patientId, encounterId: result.encounterId });
        setConnection('syncing');
        await refreshTimeline(result.patientId);
        setTab('history');
      } catch (e) {
        setError(e instanceof Error ? e.message : 'failed to start demo encounter');
      } finally {
        setStarting(false);
      }
    },
    [refreshTimeline],
  );

  const handleEvent = useCallback(
    async (event: ClinicalEvent) => {
      if (!demo) return;
      setConnection('syncing');
      setError(null);
      try {
        const next = await sendEvent(demo.patientId, demo.encounterId, event);
        setProjection(next);
        await refreshTimeline(demo.patientId);
        setConnection('online');
      } catch (e) {
        setError(e instanceof Error ? e.message : 'event failed');
        setConnection('offline');
      }
    },
    [demo, refreshTimeline],
  );

  const phase = projection ? derivePhase(projection) : PHASES[0].id;

  return (
    <div className="workspace">
      <WorkspaceHeader connection={connection} patientId={demo?.patientId ?? null} encounterId={demo?.encounterId ?? null} />
      <EncounterPhaseBar phases={PHASES} activePhase={phase} onPhase={() => setTab('history')} />

      {error && (
        <div className="banner banner-error" role="alert">
          {error}
        </div>
      )}

      {!projection || !demo ? (
        <WelcomeGate starting={starting} onStart={handleDemo} />
      ) : (
        <>
          <PatientSnapshot projection={projection} />
          <AlertsBanner alerts={projection.alerts} />

          <nav className="tabs" aria-label="Clinical workspace">
            {TABS.map((t) => (
              <button key={t.id} className={`tab ${tab === t.id ? 'active' : ''}`} onClick={() => setTab(t.id)}>
                {t.label}
                {t.id === 'investigations' && projection.investigations.length > 0 && (
                  <span className="tab-badge">{projection.investigations.length}</span>
                )}
                {t.id === 'monitoring' && projection.alerts.length > 0 && (
                  <span className="tab-badge tab-badge-alert">{projection.alerts.length}</span>
                )}
              </button>
            ))}
          </nav>

          <main className="main">
            {tab === 'history' && (
              <div className="grid-2">
                <QuestionCard
                  projection={projection}
                  onAnswer={(questionCode, answerCode) => void handleEvent(questionAnswered(questionCode, answerCode))}
                  onSkip={(questionCode) => void handleEvent(questionSkipped(questionCode))}
                />
                <FactChips projection={projection} />
              </div>
            )}
            {tab === 'reasoning' && <ReasoningDrawer projection={projection} onClose={() => setTab('history')} />}
            {tab === 'exam' && (
              <ExaminationPanel
                modules={projection.examination}
                onFinding={(findingCode, value) => void handleEvent(examFindingCaptured(findingCode, value))}
              />
            )}
            {tab === 'investigations' && (
              <InvestigationCenter
                projection={projection}
                onDecision={(d) => void handleEvent(clinicianDecision(d))}
                onResult={(r) => void handleEvent(r.event)}
              />
            )}
            {tab === 'management' && <ManagementCenter projection={projection} />}
            {tab === 'monitoring' && <MonitoringCenter projection={projection} />}
            {tab === 'docs' && <DocumentationCenter sections={projection.documentation} />}
            {tab === 'education' && <EducationCenter education={projection.education} />}
            {tab === 'timeline' && <ClinicalTimeline entries={timeline} />}
            {tab === 'configuration' && <ConfigurationPanel projection={projection} />}
          </main>
        </>
      )}
    </div>
  );
}

// Map the CPU's currentPhase to the appropriate workspace tab section.
function derivePhase(projection: ClinicalRuntimeProjection): string {
  const server = projection.currentPhase;
  if (server === 'clinical_reasoning') return 'reasoning';
  if (PHASES.some((p) => p.id === server)) return server;
  if (projection.alerts.some((a) => a.level === 'urgent' || a.level === 'emergency')) return 'monitoring';
  if (projection.protocol) return 'management';
  if (projection.investigations.length > 0) return 'investigations';
  if (projection.examination.length > 0) return 'exam';
  if (projection.capturedFacts.length > 0) return 'history';
  return 'presentation';
}

function WelcomeGate({ starting, onStart }: { starting: boolean; onStart: (symptom: string) => void }) {
  const [symptom, setSymptom] = useState('cough');
  return (
    <div className="welcome">
      <div className="card welcome-card">
        <h1>AMEXAN Clinical Workspace</h1>
        <p className="muted">A live projection of the AMEXAN CPU. Start a demo encounter, then drive the adaptive interview, examination and investigations.</p>
        <label className="field">
          <span>Presenting symptom</span>
          <input value={symptom} onChange={(e) => setSymptom(e.target.value)} />
        </label>
        <button className="btn btn-primary" disabled={starting} onClick={() => onStart(symptom)}>
          {starting ? 'Starting…' : 'Start encounter'}
        </button>
      </div>
    </div>
  );
}