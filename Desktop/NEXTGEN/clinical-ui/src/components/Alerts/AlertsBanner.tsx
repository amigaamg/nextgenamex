import type { ReactNode } from 'react';
import type { Alert } from '../../types';
import {
  CircleSlashIcon,
  AlertTriangleIcon,
  InfoIcon,
  BellIcon,
} from '../Icons';

const LEVEL_ORDER: Record<Alert['level'], number> = {
  emergency: 0,
  urgent: 1,
  warning: 2,
  info: 3,
};

const LEVEL_LABELS: Record<Alert['level'], string> = {
  emergency: 'Emergency',
  urgent: 'Urgent',
  warning: 'Warning',
  info: 'Information',
};

const LEVEL_ICONS: Record<Alert['level'], ReactNode> = {
  emergency: <CircleSlashIcon size={16} />,
  urgent: <AlertTriangleIcon size={16} />,
  warning: <AlertTriangleIcon size={16} />,
  info: <InfoIcon size={16} />,
};

export function AlertsBanner({ alerts }: { alerts: Alert[] }) {
  if (!alerts.length) return null;

  const visibleAlerts = [...alerts].sort(
    (a, b) => (LEVEL_ORDER[a.level] ?? 99) - (LEVEL_ORDER[b.level] ?? 99),
  );

  return (
    <section
      className="alerts-banner"
      aria-label="Clinical alerts"
      aria-live="polite"
    >
      <div className="alerts-banner-header">
        <div className="alerts-banner-title">
          <span className="alerts-banner-icon" aria-hidden="true">
            <BellIcon size={18} />
          </span>
          <div>
            <h2>Clinical Alerts</h2>
            <span className="muted small">
              {visibleAlerts.length}{' '}
              {visibleAlerts.length === 1 ? 'alert' : 'alerts'} requiring review
            </span>
          </div>
        </div>

        <AlertSeveritySummary alerts={visibleAlerts} />
      </div>

      <div className="alerts-list">
        {visibleAlerts.map((alert, index) => (
          <ClinicalAlert
            key={`${alert.level}-${alert.code}-${index}`}
            alert={alert}
          />
        ))}
      </div>
    </section>
  );
}

function ClinicalAlert({ alert }: { alert: Alert }) {
  const level = alert.level;
  const label = LEVEL_LABELS[level] ?? level;
  const icon = LEVEL_ICONS[level] ?? '•';

  return (
    <article
      className={`clinical-alert clinical-alert-${level}`}
      role={level === 'emergency' || level === 'urgent' ? 'alert' : 'status'}
    >
      <div className="clinical-alert-indicator" aria-hidden="true">
        {icon}
      </div>

      <div className="clinical-alert-content">
        <div className="clinical-alert-meta">
          <span className={`alert-severity severity-${level}`}>
            {label}
          </span>

          <span className="clinical-alert-code mono">
            {alert.code}
          </span>
        </div>

        <p className="clinical-alert-message">
          {alert.message}
        </p>
      </div>
    </article>
  );
}

function AlertSeveritySummary({ alerts }: { alerts: Alert[] }) {
  const counts = alerts.reduce(
    (result, alert) => {
      if (alert.level in result) {
        result[alert.level] += 1;
      }
      return result;
    },
    {
      emergency: 0,
      urgent: 0,
      warning: 0,
      info: 0,
    } as Record<Alert['level'], number>,
  );

  return (
    <div className="alert-severity-summary" aria-label="Alert severity summary">
      {counts.emergency > 0 && (
        <span className="severity-count severity-count-emergency">
          {counts.emergency} emergency
        </span>
      )}

      {counts.urgent > 0 && (
        <span className="severity-count severity-count-urgent">
          {counts.urgent} urgent
        </span>
      )}

      {counts.warning > 0 && (
        <span className="severity-count severity-count-warning">
          {counts.warning} warning
        </span>
      )}

      {counts.info > 0 && (
        <span className="severity-count severity-count-info">
          {counts.info} info
        </span>
      )}
    </div>
  );
}