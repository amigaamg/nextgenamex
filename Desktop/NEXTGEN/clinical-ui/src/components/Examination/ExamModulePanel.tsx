// =============================================================================
// src/components/Examination/ExamModulePanel.tsx
// Renders one examination module as a card. Findings are grouped into the
// structured technique sections (Inspection → Palpation → Percussion →
// Auscultation) defined in MODULE_TECHNIQUE_SECTIONS, each with a numbered
// header so the doctor always knows the correct order. Findings without a
// technique section are appended at the end.
// =============================================================================

import type { ClinicalContext, ExaminationModule } from '../../clinical/types';
import {
  MODULE_TECHNIQUE_SECTIONS,
  type TechniqueCode,
} from '../../clinical/exam/modules';
import { FindingControl } from './FindingControl';

interface ExamModulePanelProps {
  module: ExaminationModule;
  context: ClinicalContext;
  capturedValues: Record<string, unknown>;
  hiddenFindingCodes?: string[];
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

const HIDDEN_GENERAL_SIGNS = new Set([
  'EXAM_GEN_PALLOR',
  'EXAM_GEN_PALLOR_SITE',
  'EXAM_GEN_PALLOR_SEVERITY',
  'EXAM_GEN_JAUNDICE',
  'EXAM_GEN_JAUNDICE_SITE',
  'EXAM_GEN_JAUNDICE_SEVERITY',
  'EXAM_GEN_CYANOSIS',
  'EXAM_GEN_CYANOSIS_SITE',
  'EXAM_GEN_CLUBBING',
  'EXAM_GEN_CLUBBING_SITE',
  'EXAM_GEN_EDEMA',
  'EXAM_GEN_EDEMA_SITE',
  'EXAM_GEN_EDEMA_SEVERITY',
  'EXAM_GEN_LYMPHADENOPATHY',
  'EXAM_GEN_LYMPH_NODE_SITE',
  'EXAM_GEN_CATHETER',
  'EXAM_GEN_URINE_COLOR',
  'EXAM_GEN_URINE_VOLUME',
  'EXAM_GEN_URINE_DURATION',
  'EXAM_GEN_URINE_OUTPUT_RATE',
]);

const TECHNIQUE_BADGES: Record<TechniqueCode, string> = {
  INSPECTION: '1 · Inspect',
  PALPATION_SUPERFICIAL: '2 · Palpate',
  PALPATION_DEEP: '2b · Deep palpate',
  PERCUSSION: '3 · Percuss',
  AUSCULTATION: '4 · Auscultate',
  PULSE: '5 · Pulse',
  MOVEMENT: '3 · Move',
  OTHER: '•',
};

export function ExamModulePanel({
  module,
  context,
  capturedValues,
  hiddenFindingCodes,
  onCapture,
}: ExamModulePanelProps) {
  const hidden = new Set([
    ...(hiddenFindingCodes ?? []),
    ...HIDDEN_GENERAL_SIGNS,
  ]);

  const visibleFindings = module.findings.filter(
    (finding) => !hidden.has(finding.findingCode),
  );

  const visibleByCode = new Map(
    visibleFindings.map((finding) => [finding.findingCode, finding]),
  );

  const sections = MODULE_TECHNIQUE_SECTIONS[module.moduleCode] ?? [];

  const sectionGroups = sections
    .map((section) => ({
      section,
      findings: section.findingCodes
        .map((code) => visibleByCode.get(code))
        .filter(
          (finding): finding is NonNullable<typeof finding> =>
            Boolean(finding),
        ),
    }))
    .filter((group) => group.findings.length > 0);

  const coveredCodes = new Set(
    sectionGroups.flatMap((group) =>
      group.findings.map((finding) => finding.findingCode),
    ),
  );

  const looseFindings = visibleFindings.filter(
    (finding) => !coveredCodes.has(finding.findingCode),
  );

  return (
    <section className="exam-module-card">
      <header className="exam-module-head">
        <div>
          <h2 className="exam-module-title">{module.name}</h2>
          {module.required && (
            <span className="exam-module-required">Required</span>
          )}
        </div>
        <span className="exam-module-code">{module.moduleCode}</span>
      </header>

      <div className="exam-module-body">
        {sectionGroups.map(({ section, findings }) => (
          <div
            key={`${section.code}-${section.step}`}
            className="exam-technique"
          >
            <header className="exam-technique-head">
              <span className="exam-technique-badge">
                {TECHNIQUE_BADGES[section.code]}
              </span>
              <span className="exam-technique-name">
                {section.technique}
              </span>
            </header>

            <div className="exam-technique-findings">
              {findings.map((finding) => (
                <FindingControl
                  key={finding.findingCode}
                  finding={finding}
                  context={context}
                  value={capturedValues[finding.findingCode]}
                  onCapture={(value, unit) =>
                    onCapture(finding.findingCode, value, unit)
                  }
                />
              ))}
            </div>
          </div>
        ))}

        {looseFindings.map((finding) => (
          <FindingControl
            key={finding.findingCode}
            finding={finding}
            context={context}
            value={capturedValues[finding.findingCode]}
            onCapture={(value, unit) =>
              onCapture(finding.findingCode, value, unit)
            }
          />
        ))}
      </div>
    </section>
  );
}