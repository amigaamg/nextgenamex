// =============================================================================
// src/components/Examination/SignsPanel.tsx
// General-exam physical signs with speed-first capture:
//   each sign (pallor, jaundice, cyanosis, clubbing, edema, lymphadenopathy)
//   is reported Absent or Present; when present the clinician taps one or more
//   site chips and a severity grade (+ = mild, ++ = moderate, +++ = severe).
// =============================================================================

import {
  EDEMA_SITES,
  JAUNDICE_SITES,
  LYMPH_NODE_GROUPS,
  PALLOR_SITES,
  signGradeDescription,
} from '../../clinical/exam/norms';

interface SignsPanelProps {
  capturedValues: Record<string, unknown>;
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

interface SignConfig {
  key: string; // e.g. 'PALLOR'
  label: string;
  presenceCode: string; // e.g. EXAM_GEN_PALLOR
  siteCode: string; // e.g. EXAM_GEN_PALLOR_SITE
  severityCode: string; // e.g. EXAM_GEN_PALLOR_SEVERITY
  siteOptions: string[];
  showSeverity: boolean;
}

const SIGNS: SignConfig[] = [
  {
    key: 'PALLOR',
    label: 'Pallor',
    presenceCode: 'EXAM_GEN_PALLOR',
    siteCode: 'EXAM_GEN_PALLOR_SITE',
    severityCode: 'EXAM_GEN_PALLOR_SEVERITY',
    siteOptions: PALLOR_SITES,
    showSeverity: true,
  },
  {
    key: 'JAUNDICE',
    label: 'Jaundice',
    presenceCode: 'EXAM_GEN_JAUNDICE',
    siteCode: 'EXAM_GEN_JAUNDICE_SITE',
    severityCode: 'EXAM_GEN_JAUNDICE_SEVERITY',
    siteOptions: JAUNDICE_SITES,
    showSeverity: true,
  },
  {
    key: 'CYANOSIS',
    label: 'Cyanosis',
    presenceCode: 'EXAM_GEN_CYANOSIS',
    siteCode: 'EXAM_GEN_CYANOSIS_SITE',
    severityCode: 'EXAM_GEN_CYANOSIS_SEVERITY',
    siteOptions: ['Peripheral', 'Central (lips/tongue)'],
    showSeverity: false,
  },
  {
    key: 'CLUBBING',
    label: 'Finger clubbing',
    presenceCode: 'EXAM_GEN_CLUBBING',
    siteCode: 'EXAM_GEN_CLUBBING_SITE',
    severityCode: 'EXAM_GEN_CLUBBING_SEVERITY',
    siteOptions: ['Bilateral', 'Unilateral'],
    showSeverity: false,
  },
  {
    key: 'EDEMA',
    label: 'Edema',
    presenceCode: 'EXAM_GEN_EDEMA',
    siteCode: 'EXAM_GEN_EDEMA_SITE',
    severityCode: 'EXAM_GEN_EDEMA_SEVERITY',
    siteOptions: EDEMA_SITES,
    showSeverity: true,
  },
  {
    key: 'LYMPHADENOPATHY',
    label: 'Lymphadenopathy',
    presenceCode: 'EXAM_GEN_LYMPHADENOPATHY',
    siteCode: 'EXAM_GEN_LYMPH_NODE_SITE',
    severityCode: 'EXAM_GEN_LYMPH_NODE_SEVERITY',
    siteOptions: LYMPH_NODE_GROUPS,
    showSeverity: false,
  },
];

const SEVERITIES = ['+', '++', '+++'];

function SignRow({
  sign,
  capturedValues,
  onCapture,
}: {
  sign: SignConfig;
  capturedValues: Record<string, unknown>;
  onCapture: SignsPanelProps['onCapture'];
}) {
  const present = capturedValues[sign.presenceCode] === true;

  const siteValue = capturedValues[sign.siteCode];
  const selectedSites: string[] = Array.isArray(siteValue)
    ? (siteValue as string[])
    : typeof siteValue === 'string' && siteValue !== ''
      ? (siteValue as string).split('; ')
      : [];

  const severity =
    typeof capturedValues[sign.severityCode] === 'string'
      ? (capturedValues[sign.severityCode] as string)
      : '';

  const toggleSite = (site: string) => {
    const next = selectedSites.includes(site)
      ? selectedSites.filter((existing) => existing !== site)
      : [...selectedSites, site];
    onCapture(sign.siteCode, next.length > 0 ? next : null);
  };

  return (
    <div className="sign-row">
      <div className="sign-head">
        <span className="sign-name">{sign.label}</span>

        <div className="presence-row">
          <button
            type="button"
            className={`presence-option positive ${present ? 'active' : ''}`}
            onClick={() => {
              onCapture(sign.presenceCode, true);
            }}
          >
            Present
          </button>
          <button
            type="button"
            className={`presence-option negative ${present === false ? 'active' : ''}`}
            onClick={() => {
              onCapture(sign.presenceCode, false);
              onCapture(sign.siteCode, null);
              onCapture(sign.severityCode, null);
            }}
          >
            Absent
          </button>
        </div>
      </div>

      {present && (
        <div className="sign-detail">
          <div className="sign-chip-group">
            <span className="sign-chip-label">Site(s)</span>
            <div className="chip-row">
              {sign.siteOptions.map((site) => (
                <button
                  key={site}
                  type="button"
                  className={`chip ${selectedSites.includes(site) ? 'active' : ''}`}
                  onClick={() => toggleSite(site)}
                >
                  {site}
                </button>
              ))}
            </div>
          </div>

          {sign.showSeverity && (
            <div className="sign-severity">
              <span className="sign-chip-label">Severity</span>
              <div className="severity-row">
                {SEVERITIES.map((grade) => (
                  <button
                    key={grade}
                    type="button"
                    className={`severity-option ${severity === grade ? 'active' : ''}`}
                    title={signGradeDescription(grade)}
                    onClick={() =>
                      onCapture(sign.severityCode, grade)
                    }
                  >
                    {grade}
                    <span className="severity-word">
                      {signGradeDescription(grade)}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export function SignsPanel({
  capturedValues,
  onCapture,
}: SignsPanelProps) {
  return (
    <section className="exam-module-card">
      <header className="exam-module-head">
        <div>
          <h2 className="exam-module-title">General Signs</h2>
          <span className="exam-module-required">Pallor · Jaundice · Cyanosis · Clubbing · Edema · Lymphadenopathy</span>
        </div>
        <span className="exam-module-code">SIGNS</span>
      </header>

      <div className="exam-module-body">
        {SIGNS.map((sign) => (
          <SignRow
            key={sign.key}
            sign={sign}
            capturedValues={capturedValues}
            onCapture={onCapture}
          />
        ))}
      </div>
    </section>
  );
}