import type { Alert } from '../../types';

export function AlertsBanner({ alerts }: { alerts: Alert[] }) {
  if (alerts.length === 0) return null;
  return (
    <div className="alerts" aria-label="Clinical alerts">
      {alerts.map((a) => (
        <div key={`${a.level}-${a.code}`} className={`alert alert-${a.level}`}>
          <span className="alert-level">{a.level}</span>
          <span className="alert-message">{a.message}</span>
          <span className="muted small mono">{a.code}</span>
        </div>
      ))}
    </div>
  );
}