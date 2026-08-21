// =============================================================================
// src/components/Examination/ExamSidebar.tsx
// Fast phase navigation for the examination workspace.
// =============================================================================

import type { ExaminationPhase } from '../../clinical/exam/modules';

interface ExamSidebarProps {
  phases: ExaminationPhase[];
  activePhase: ExaminationPhase;
  completedPhases: Set<string>;
  capturedCount: number;
  totalCount: number;
  onPhaseChange: (phaseCode: string) => void;
}

const PHASE_ICONS: Record<string, string> = {
  ANTHROPOMETRY: '📏',
  GENERAL: '🩺',
  VITALS: '🌡️',
  SYSTEMS: '🫀',
  LOCAL: '🔍',
  SPECIAL: '🎯',
};

export function ExamSidebar({
  phases,
  activePhase,
  completedPhases,
  capturedCount,
  totalCount,
  onPhaseChange,
}: ExamSidebarProps) {
  return (
    <aside className="exam-sidebar">
      <div className="exam-sidebar-head">
        <h3 className="exam-sidebar-title">Examination</h3>
        <span className="exam-sidebar-count">
          {capturedCount}/{totalCount}
        </span>
      </div>

      <nav className="exam-phase-list" aria-label="Examination phases">
        {phases.map((phase, index) => {
          const isActive = phase.phaseCode === activePhase.phaseCode;
          const isComplete = completedPhases.has(phase.phaseCode);

          return (
            <button
              key={phase.phaseCode}
              type="button"
              className={[
                'exam-phase-item',
                isActive ? 'active' : '',
                isComplete ? 'complete' : '',
              ].join(' ')}
              onClick={() => onPhaseChange(phase.phaseCode)}
              aria-current={isActive ? 'step' : undefined}
            >
              <span className="exam-phase-index">{index + 1}</span>

              <span className="exam-phase-icon" aria-hidden="true">
                {PHASE_ICONS[phase.phaseCode] ?? '·'}
              </span>

              <span className="exam-phase-label">
                {phase.label}
              </span>

              <span className="exam-phase-check" aria-hidden="true">
                {isComplete ? '✓' : ''}
              </span>
            </button>
          );
        })}
      </nav>

      <div className="exam-sidebar-foot">
        <p className="exam-sidebar-hint">
          All findings are captured in the structured clinical record.
        </p>
      </div>
    </aside>
  );
}
