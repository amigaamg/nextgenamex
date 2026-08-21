// =============================================================================
// AMEXAN System Versions — the version matrix (application vs database vs
// knowledge vs rules).
// IMPROVE / INVESTIGATE. Read-only.
// =============================================================================

import { useCallback, useEffect, useMemo, useState } from 'react';
import { getSystemVersions } from '../api';
import type { SystemVersionsResponse } from '../types';

function formatDate(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleString();
}

function formatDateOnly(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleDateString();
}

function VersionValue({
  value,
}: {
  value: string | null | undefined;
}) {
  return (
    <span className="mono">
      {value && value.trim() ? value : '—'}
    </span>
  );
}

function ActiveBadge() {
  return <span className="admin-badge ok">ACTIVE</span>;
}

function VersionCard({
  label,
  value,
  active = false,
}: {
  label: string;
  value: string | null | undefined;
  active?: boolean;
}) {
  return (
    <div className="admin-panel">
      <div className="admin-panel-head">
        <span className="admin-panel-title">{label}</span>
        {active && <ActiveBadge />}
      </div>

      <div
        style={{
          padding: '14px 16px',
          fontSize: '1rem',
          fontWeight: 600,
          overflowWrap: 'anywhere',
        }}
      >
        <VersionValue value={value} />
      </div>
    </div>
  );
}

export function VersionsView() {
  const [data, setData] = useState<SystemVersionsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [showInactive, setShowInactive] = useState(true);

  const load = useCallback(async (background = false) => {
    if (background) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }

    setError(null);

    try {
      const response = await getSystemVersions();
      setData(response);
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : 'Failed to load system versions',
      );
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const versions = data?.systemVersions ?? [];

  const filteredVersions = useMemo(() => {
    const query = search.trim().toLowerCase();

    return versions.filter((version) => {
      if (!showInactive && !version.isActive) {
        return false;
      }

      if (!query) {
        return true;
      }

      const searchable = [
        version.systemVersionCode,
        version.reasoningVersionCode,
        version.documentationVersionCode,
        version.differentialVersionCode,
        version.engineVersion,
        version.releaseNotes,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();

      return searchable.includes(query);
    });
  }, [versions, search, showInactive]);

  const activeVersion = useMemo(
    () => versions.find((version) => version.isActive) ?? null,
    [versions],
  );

  const releaseNotes = useMemo(
    () =>
      filteredVersions.filter(
        (version) =>
          typeof version.releaseNotes === 'string' &&
          version.releaseNotes.trim().length > 0,
      ),
    [filteredVersions],
  );

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span className="admin-spinner" aria-hidden="true" />
        Loading system versions…
      </div>
    );
  }

  if (error && !data) {
    return <div className="admin-error">{error}</div>;
  }

  return (
    <div>
      {/* ================================================================== */}
      {/* HEADER / STATUS                                                   */}
      {/* ================================================================== */}

      <div className="admin-panel">
        <div className="admin-panel-head">
          <div>
            <span className="admin-panel-title">
              AMEXAN System Version Matrix
            </span>

            <span className="admin-panel-sub">
              governance.system_version · {versions.length} released
              {refreshing ? ' · refreshing…' : ''}
            </span>
          </div>

          <button
            type="button"
            className="admin-page-btn"
            onClick={() => void load(true)}
            disabled={refreshing}
            aria-label="Refresh system versions"
          >
            {refreshing ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>

        {error && (
          <div className="admin-error" style={{ margin: 12 }}>
            {error}
          </div>
        )}

        <div className="admin-filters">
          <input
            type="search"
            className="admin-filter-input"
            placeholder="Search versions, engines, reasoning, documentation…"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            aria-label="Search system versions"
          />

          <label
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              whiteSpace: 'nowrap',
            }}
          >
            <input
              type="checkbox"
              checked={showInactive}
              onChange={(event) => setShowInactive(event.target.checked)}
            />
            Show inactive
          </label>
        </div>
      </div>

      {/* ================================================================== */}
      {/* CURRENT ACTIVE SYSTEM                                             */}
      {/* ================================================================== */}

      {activeVersion && (
        <>
          <div className="admin-panel">
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Active AMEXAN Runtime
              </span>

              <span className="admin-panel-sub">
                currently governed system version
              </span>
            </div>

            <div className="admin-kv">
              <span className="k">System version</span>
              <span className="v">
                <span className="mono">
                  {activeVersion.systemVersionCode}
                </span>{' '}
                <ActiveBadge />
              </span>

              <span className="k">Reasoning</span>
              <span className="v">
                <VersionValue value={activeVersion.reasoningVersionCode} />
              </span>

              <span className="k">Documentation</span>
              <span className="v">
                <VersionValue
                  value={activeVersion.documentationVersionCode}
                />
              </span>

              <span className="k">Differential</span>
              <span className="v">
                <VersionValue
                  value={activeVersion.differentialVersionCode}
                />
              </span>

              <span className="k">Engine</span>
              <span className="v">
                <VersionValue value={activeVersion.engineVersion} />
              </span>

              <span className="k">Released</span>
              <span className="v mono">
                {formatDate(activeVersion.releasedAt)}
              </span>
            </div>
          </div>

          <div className="admin-grid-3">
            <VersionCard
              label="System"
              value={activeVersion.systemVersionCode}
              active
            />

            <VersionCard
              label="Reasoning"
              value={activeVersion.reasoningVersionCode}
            />

            <VersionCard
              label="Documentation"
              value={activeVersion.documentationVersionCode}
            />

            <VersionCard
              label="Differential"
              value={activeVersion.differentialVersionCode}
            />

            <VersionCard
              label="Engine"
              value={activeVersion.engineVersion}
            />

            <VersionCard
              label="Release"
              value={formatDateOnly(activeVersion.releasedAt)}
            />
          </div>
        </>
      )}

      {/* ================================================================== */}
      {/* VERSION REGISTRY                                                   */}
      {/* ================================================================== */}

      <div className="admin-panel">
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            System Version Registry
          </span>

          <span className="admin-panel-sub">
            {filteredVersions.length} of {versions.length} versions shown
          </span>
        </div>

        {versions.length === 0 && (
          <div className="admin-empty">
            No system versions recorded.
          </div>
        )}

        {versions.length > 0 && filteredVersions.length === 0 && (
          <div className="admin-empty">
            No system versions match the current filter.
          </div>
        )}

        {filteredVersions.length > 0 && (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>System version</th>
                  <th>Reasoning</th>
                  <th>Documentation</th>
                  <th>Differential</th>
                  <th>Engine</th>
                  <th>Released</th>
                  <th>Status</th>
                </tr>
              </thead>

              <tbody>
                {filteredVersions.map((version) => (
                  <tr key={version.id}>
                    <td className="mono">
                      {version.systemVersionCode}
                    </td>

                    <td>
                      <VersionValue
                        value={version.reasoningVersionCode}
                      />
                    </td>

                    <td>
                      <VersionValue
                        value={version.documentationVersionCode}
                      />
                    </td>

                    <td>
                      <VersionValue
                        value={version.differentialVersionCode}
                      />
                    </td>

                    <td>
                      <VersionValue value={version.engineVersion} />
                    </td>

                    <td className="mono">
                      {formatDate(version.releasedAt)}
                    </td>

                    <td>
                      {version.isActive ? (
                        <ActiveBadge />
                      ) : (
                        <span className="admin-badge">
                          INACTIVE
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ================================================================== */}
      {/* RELEASE NOTES                                                       */}
      {/* ================================================================== */}

      {releaseNotes.length > 0 && (
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Release Notes
            </span>

            <span className="admin-panel-sub">
              {releaseNotes.length} version
              {releaseNotes.length === 1 ? '' : 's'}
            </span>
          </div>

          {releaseNotes.map((version) => (
            <details
              key={version.id}
              className="admin-table-details"
              style={{
                margin: '0 12px 12px',
              }}
              open={version.isActive}
            >
              <summary
                style={{
                  cursor: 'pointer',
                  padding: '10px 4px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                }}
              >
                <strong className="mono">
                  {version.systemVersionCode}
                </strong>

                {version.isActive && <ActiveBadge />}

                <span className="muted small">
                  {formatDate(version.releasedAt)}
                </span>
              </summary>

              <pre
                className="admin-json"
                style={{
                  maxHeight: 320,
                  overflow: 'auto',
                  whiteSpace: 'pre-wrap',
                  overflowWrap: 'anywhere',
                }}
              >
                {version.releaseNotes}
              </pre>
            </details>
          ))}
        </div>
      )}

      {/* ================================================================== */}
      {/* VERSION CONSISTENCY CHECK                                          */}
      {/* ================================================================== */}

      {activeVersion && (
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Active Version Consistency
            </span>

            <span className="admin-panel-sub">
              component versions attached to the active release
            </span>
          </div>

          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Component</th>
                  <th>Version</th>
                  <th>State</th>
                </tr>
              </thead>

              <tbody>
                <tr>
                  <td>System</td>
                  <td className="mono">
                    {activeVersion.systemVersionCode}
                  </td>
                  <td>
                    <span className="admin-badge ok">
                      ACTIVE
                    </span>
                  </td>
                </tr>

                <tr>
                  <td>Reasoning</td>
                  <td className="mono">
                    {activeVersion.reasoningVersionCode ?? '—'}
                  </td>
                  <td>
                    {activeVersion.reasoningVersionCode ? (
                      <span className="admin-badge ok">
                        PRESENT
                      </span>
                    ) : (
                      <span className="admin-badge warn">
                        NOT DECLARED
                      </span>
                    )}
                  </td>
                </tr>

                <tr>
                  <td>Documentation</td>
                  <td className="mono">
                    {activeVersion.documentationVersionCode ?? '—'}
                  </td>
                  <td>
                    {activeVersion.documentationVersionCode ? (
                      <span className="admin-badge ok">
                        PRESENT
                      </span>
                    ) : (
                      <span className="admin-badge warn">
                        NOT DECLARED
                      </span>
                    )}
                  </td>
                </tr>

                <tr>
                  <td>Differential</td>
                  <td className="mono">
                    {activeVersion.differentialVersionCode ?? '—'}
                  </td>
                  <td>
                    {activeVersion.differentialVersionCode ? (
                      <span className="admin-badge ok">
                        PRESENT
                      </span>
                    ) : (
                      <span className="admin-badge warn">
                        NOT DECLARED
                      </span>
                    )}
                  </td>
                </tr>

                <tr>
                  <td>Engine</td>
                  <td className="mono">
                    {activeVersion.engineVersion ?? '—'}
                  </td>
                  <td>
                    {activeVersion.engineVersion ? (
                      <span className="admin-badge ok">
                        PRESENT
                      </span>
                    ) : (
                      <span className="admin-badge warn">
                        NOT DECLARED
                      </span>
                    )}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}