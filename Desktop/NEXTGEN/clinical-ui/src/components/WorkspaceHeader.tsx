export function WorkspaceHeader({
  connection,
  patientId,
  encounterId,
}: {
  connection: 'offline' | 'syncing' | 'online';
  patientId: string | null;
  encounterId: string | null;
}) {
  const dot = connection === 'online' ? 'dot-online' : connection === 'syncing' ? 'dot-syncing' : 'dot-offline';
  return (
    <header className="workspace-header">
      <div className="brand">
        <span className="brand-mark">◈</span> AMEXAN
      </div>
      <div className="header-facility">Kisii Teaching &amp; Referral Hospital</div>
      <div className="header-right">
        {patientId && (
          <span className="muted mono" title="patientId">
            {patientId.slice(0, 8)}
          </span>
        )}
        {encounterId && (
          <span className="muted mono" title="encounterId">
            ENC-{encounterId.slice(0, 6).toUpperCase()}
          </span>
        )}
        <span className={`sync-state ${dot}`} title={`realtime: ${connection}`}>
          {connection === 'online' ? 'Live' : connection === 'syncing' ? 'Syncing…' : 'Offline'}
        </span>
      </div>
    </header>
  );
}
