import type { ClinicalRuntimeProjection, ClinicalUIState } from '../../types';

interface CPUStatusBarProps {
  uiState: ClinicalUIState | null;
  projection: ClinicalRuntimeProjection | null;
}

type TaskPriority = 'emergency' | 'urgent' | 'important' | 'routine';

const PRIORITY_CONFIG: Record<
  TaskPriority,
  {
    label: string;
    className: string;
    indicator: string;
  }
> = {
  emergency: {
    label: 'Emergency',
    className: 'status-emergency',
    indicator: '●',
  },
  urgent: {
    label: 'Urgent',
    className: 'status-urgent',
    indicator: '●',
  },
  important: {
    label: 'Important',
    className: 'status-important',
    indicator: '●',
  },
  routine: {
    label: 'Routine',
    className: 'status-routine',
    indicator: '●',
  },
};

export function CPUStatusBar({
  uiState,
  projection,
}: CPUStatusBarProps) {
  if (!uiState || !projection) {
    return null;
  }

  const priority = normalizePriority(uiState.task.priority);
  const priorityConfig = PRIORITY_CONFIG[priority];

  const confidence =
    typeof uiState.confidence === 'number'
      ? clamp(uiState.confidence, 0, 1)
      : null;

  const taskLabel = formatTaskType(uiState.task.type);

  const blockingIssues = Array.isArray(uiState.blockingIssues)
    ? uiState.blockingIssues.filter(Boolean)
    : [];

  return (
    <section
      className="cpu-status-bar"
      aria-label="Clinical CPU status"
    >
      <StatusItem
        label="CPU status"
        className="cpu-priority-status"
      >
        <span
          className={`status-indicator ${priorityConfig.className}`}
          aria-label={`Priority: ${priorityConfig.label}`}
        >
          <span
            className="status-indicator-dot"
            aria-hidden="true"
          >
            {priorityConfig.indicator}
          </span>
          <span>{priorityConfig.label}</span>
        </span>
      </StatusItem>

      <StatusItem label="Current task">
        <div className="cpu-task">
          <strong>{taskLabel}</strong>

          {uiState.task.code && (
            <span className="task-code mono">
              {uiState.task.code}
            </span>
          )}
        </div>
      </StatusItem>

      <StatusItem
        label="Next best action"
        className="status-next-action"
      >
        <div className="next-action">
          <strong className="next-action-label">
            {uiState.nextAction.label}
          </strong>

          {uiState.nextAction.rationale && (
            <span className="next-action-rationale">
              {uiState.nextAction.rationale}
            </span>
          )}
        </div>
      </StatusItem>

      {confidence !== null && (
        <StatusItem label="Confidence">
          <ConfidenceMeter value={confidence} />
        </StatusItem>
      )}

      {blockingIssues.length > 0 && (
        <StatusItem
          label="Blocking issues"
          className="blocking-issues"
        >
          <div className="blocking-summary">
            <span className="blocking-count">
              {blockingIssues.length}
            </span>

            <ul className="blocking-list">
              {blockingIssues.map((issue, index) => (
                <li
                  key={`${issue}-${index}`}
                  className="blocking-item"
                >
                  {issue}
                </li>
              ))}
            </ul>
          </div>
        </StatusItem>
      )}
    </section>
  );
}

function StatusItem({
  label,
  children,
  className = '',
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`status-section ${className}`.trim()}>
      <div className="status-label">{label}</div>
      <div className="status-value">{children}</div>
    </div>
  );
}

function ConfidenceMeter({
  value,
}: {
  value: number;
}) {
  const percentage = Math.round(value * 100);

  return (
    <div
      className="confidence-meter"
      role="progressbar"
      aria-label="Clinical reasoning confidence"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={percentage}
    >
      <div className="confidence-track">
        <div
          className="confidence-fill"
          style={{ width: `${percentage}%` }}
        />
      </div>

      <span className="confidence-text">
        {percentage}%
      </span>
    </div>
  );
}

function normalizePriority(
  priority: string | null | undefined,
): TaskPriority {
  switch (priority) {
    case 'emergency':
    case 'urgent':
    case 'important':
      return priority;
    default:
      return 'routine';
  }
}

function formatTaskType(
  type: string | null | undefined,
): string {
  if (!type) {
    return 'Clinical assessment';
  }

  return type
    .replace(/[_-]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function clamp(
  value: number,
  min: number,
  max: number,
): number {
  return Math.min(Math.max(value, min), max);
}