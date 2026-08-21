// =============================================================================
// src/components/Examination/ExamWorkspace.tsx
// AMEXAN — FAST EXAMINATION CAPTURE WORKSPACE
//
// Speed-first design:
//   - one tab per phase (Anthropometry → General → Vitals → Systems →
//     Local → Special) so the clinician always knows where they are,
//   - large touch/click targets,
//   - Enter/arrow-key friendly controls,
//   - live deductions from the knowledge base (norms.ts) shown inline,
//   - every value saved immediately and forwarded to the CPU as facts.
// =============================================================================

import { useMemo, useState } from 'react';
import type { ClinicalContext } from '../../clinical/types';
import {
  ALL_EXAMINATION_MODULES,
  EXAMINATION_PHASES,
  EXAMINATION_MODULES_BY_CODE,
} from '../../clinical/exam/modules';
import { ExamModulePanel } from './ExamModulePanel';
import { ExamSidebar } from './ExamSidebar';
import { ExamSummaryStrip } from './ExamSummaryStrip';
import { ExamFindingsSummary } from './ExamFindingsSummary';
import { AnthropometryPanel } from './AnthropometryPanel';
import { CatheterPanel } from './CatheterPanel';
import { VitalsPanel } from './VitalsPanel';
import { SignsPanel } from './SignsPanel';

export interface ExamWorkspaceProps {
  context: ClinicalContext;
  capturedValues: Record<string, unknown>;
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

export function ExamWorkspace({
  context,
  capturedValues,
  onCapture,
}: ExamWorkspaceProps) {
  const [activePhaseCode, setActivePhaseCode] =
    useState<string>(EXAMINATION_PHASES[0].phaseCode);

  const activePhase = useMemo(
    () =>
      EXAMINATION_PHASES.find(
        (phase) => phase.phaseCode === activePhaseCode,
      ) ?? EXAMINATION_PHASES[0],
    [activePhaseCode],
  );

  const activeModules = useMemo(
    () =>
      activePhase.moduleCodes
        .map((code) => EXAMINATION_MODULES_BY_CODE[code])
        .filter(Boolean),
    [activePhase],
  );

  const completedPhases = useMemo(() => {
    const done = new Set<string>();

    for (const phase of EXAMINATION_PHASES) {
      const codes = phase.moduleCodes.flatMap(
        (code) =>
          EXAMINATION_MODULES_BY_CODE[code]?.findings.map(
            (finding) => finding.findingCode,
          ) ?? [],
      );

      const allCaptured = codes.every(
        (code) => capturedValues[code] !== undefined,
      );

      if (allCaptured) done.add(phase.phaseCode);
    }

    return done;
  }, [capturedValues]);

  const nextPhase = useMemo(
    () =>
      EXAMINATION_PHASES.find(
        (phase) =>
          !completedPhases.has(phase.phaseCode) &&
          phase.phaseCode !== activePhase.phaseCode,
      ),
    [completedPhases, activePhase.phaseCode],
  );

  const totalFindings = useMemo(
    () =>
      ALL_EXAMINATION_MODULES.reduce(
        (sum, module) => sum + module.findings.length,
        0,
      ),
    [],
  );

  const capturedCount = useMemo(
    () =>
      Object.values(capturedValues).filter(
        (value) => value !== undefined,
      ).length,
    [capturedValues],
  );

  return (
    <div className="exam-workspace w-full min-w-0">
      <ExamSidebar
        phases={EXAMINATION_PHASES}
        activePhase={activePhase}
        completedPhases={completedPhases}
        capturedCount={capturedCount}
        totalCount={totalFindings}
        onPhaseChange={setActivePhaseCode}
      />

      <div className="exam-main min-w-0">
        <ExamSummaryStrip
          context={context}
          capturedValues={capturedValues}
        />

        {activePhase.phaseCode === 'ANTHROPOMETRY' && (
          <AnthropometryPanel
            context={context}
            capturedValues={capturedValues}
            onCapture={onCapture}
          />
        )}

        {activeModules
          .filter(
            (module) =>
              module.moduleCode !== 'ANTHROPO' &&
              module.moduleCode !== 'VITALS',
          )
          .map((module) => (
            <ExamModulePanel
              key={module.moduleCode}
              module={module}
              context={context}
              capturedValues={capturedValues}
              onCapture={onCapture}
            />
          ))}

        {activePhase.phaseCode === 'GENERAL' && (
          <CatheterPanel
            context={context}
            capturedValues={capturedValues}
            onCapture={onCapture}
          />
        )}

        {activePhase.phaseCode === 'GENERAL' && (
          <SignsPanel
            capturedValues={capturedValues}
            onCapture={onCapture}
          />
        )}

        {activePhase.phaseCode === 'VITALS' && (
          <VitalsPanel
            context={context}
            capturedValues={capturedValues}
            onCapture={onCapture}
          />
        )}

        <ExamFindingsSummary
          capturedValues={capturedValues}
          context={context}
        />

        <div className="exam-footer">
          <span className="text-xs text-muted">
            Every value is saved immediately and forwarded to the clinical
            CPU for documentation and reasoning.
          </span>

          {nextPhase && (
            <button
              type="button"
              className="exam-next-btn"
              onClick={() => setActivePhaseCode(nextPhase.phaseCode)}
            >
              Next: {nextPhase.label} →
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
