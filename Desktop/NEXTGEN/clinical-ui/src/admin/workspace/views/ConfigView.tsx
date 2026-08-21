// =============================================================================
// AMEXAN Configuration — effective configuration, provenance and overrides.
// OPERATE / INVESTIGATE / IMPROVE. Read-only.
// =============================================================================

import { useCallback, useEffect, useMemo, useState } from 'react';

import {
  getConfiguration,
  getConfigurationDetail,
} from '../api';

import type {
  ConfigurationDetail,
  ConfigurationResponse,
  ConfigurationEntry,
} from '../types';

function formatDateTime(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleString();
}

function ScopeBadge({
  code,
  label,
}: {
  code: string;
  label: string;
}) {
  return (
    <span
      className="admin-badge"
      title={`Precedence ${code}`}
    >
      {label}
    </span>
  );
}

function ActiveBadge() {
  return <span className="admin-badge ok">ACTIVE</span>;
}

export function ConfigView() {
  const [data, setData] = useState<ConfigurationResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [showInactive, setShowInactive] = useState(true);
  const [scopeFilter, setScopeFilter] = useState<string>('ALL');
  const [selected, setSelected] = useState<ConfigurationDetail | null>(null);

  const load = useCallback(async (background = false) => {
    if (background) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }

    setError(null);

    try {
      const response = await getConfiguration();
      setData(response);
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : 'Failed to load configuration',
      );
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const configurations = data?.configurations ?? [];
  const scopes = data?.scopes ?? [];

  const scopedMap = useMemo(() => {
    const map = new Map<string, Set<string>>();

    for (const entry of configurations) {
      const scopesForEntry = map.get(entry.key) ?? new Set<string>();
      scopesForEntry.add(entry.code);
      map.set(entry.key, scopesForEntry);
    }

    return map;
  }, [configurations]);

  const filteredConfigurations = useMemo(() => {
    const query = search.trim().toLowerCase();

    return configurations.filter((entry) => {
      if (!showInactive && !entry.isActive) {
        return false;
      }

      if (scopeFilter !== 'ALL' && entry.code !== scopeFilter) {
        return false;
      }

      if (!query) {
        return true;
      }

      const searchable = [
        entry.key,
        entry.name,
        entry.description,
        entry.dataType,
        entry.activeValue,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();

      return searchable.includes(query);
    });
  }, [configurations, search, showInactive, scopeFilter]);

  const activeCount = useMemo(
    () => configurations.filter((entry) => entry.isActive).length,
    [configurations],
  );

  const openDetail = useCallback(
    async (entry: ConfigurationEntry) => {
      setError(null);

      try {
        const detail = await getConfigurationDetail(entry.key);
        setSelected(detail);
      } catch (e) {
        setError(
          e instanceof Error
            ? e.message
            : 'Failed to load configuration detail',
        );
      }
    },
    [],
  );

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span className="admin-spinner" aria-hidden="true" />
        Loading configuration…
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
              Effective Configuration Registry
            </span>

            <span className="admin-panel-sub">
              configuration.configuration · {activeCount} active ·{' '}
              {scopes.length} scopes
              {refreshing ? ' · refreshing…' : ''}
            </span>
          </div>

          <button
            type="button"
            className="admin-page-btn"
            onClick={() => void load(true)}
            disabled={refreshing}
            aria-label="Refresh configuration"
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
            placeholder="Search keys, names, values, descriptions…"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            aria-label="Search configuration"
          />

          <select
            className="admin-filter-input"
            value={scopeFilter}
            onChange={(event) => setScopeFilter(event.target.value)}
            aria-label="Filter configuration scope"
            style={{ maxWidth: 220 }}
          >
            <option value="ALL">All scopes</option>
            {scopes.map((scope) => (
              <option key={scope.code} value={scope.code}>
                {scope.label}
              </option>
            ))}
          </select>

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
      {/* SCOPE PRECEDENCE                                                   */}
      {/* ================================================================== */}

      {scopes.length > 0 && (
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Configuration Scopes
            </span>

            <span className="admin-panel-sub">
              resolution precedence across the configuration tree
            </span>
          </div>

          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Scope</th>
                  <th>Label</th>
                  <th>Precedence</th>
                </tr>
              </thead>

              <tbody>
                {scopes.map((scope) => (
                  <tr key={scope.code}>
                    <td className="mono">{scope.code}</td>
                    <td>{scope.label}</td>
                    <td className="mono">{scope.precedence}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ================================================================== */}
      {/* CONFIGURATION ENTRIES                                              */}
      {/* ================================================================== */}

      <div className="admin-panel">
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Configuration Entries
          </span>

          <span className="admin-panel-sub">
            {filteredConfigurations.length} of {configurations.length} shown
          </span>
        </div>

        {configurations.length === 0 && (
          <div className="admin-empty">
            No configuration entries recorded.
          </div>
        )}

        {configurations.length > 0 &&
          filteredConfigurations.length === 0 && (
            <div className="admin-empty">
              No configuration entries match the current filter.
            </div>
          )}

        {filteredConfigurations.length > 0 && (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Key</th>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Active value</th>
                  <th>Scopes</th>
                  <th>Status</th>
                  <th>Active since</th>
                </tr>
              </thead>

              <tbody>
                {filteredConfigurations.map((entry) => (
                  <tr
                    key={entry.id}
                    onClick={() => void openDetail(entry)}
                    style={{ cursor: 'pointer' }}
                    title={`Open ${entry.key} detail`}
                  >
                    <td className="mono">{entry.key}</td>
                    <td>
                      <strong>{entry.name}</strong>
                      {entry.description && (
                        <div className="muted small">
                          {entry.description}
                        </div>
                      )}
                    </td>
                    <td>
                      <span className="admin-badge">{entry.dataType}</span>
                    </td>
                    <td className="mono" style={{ maxWidth: 260 }}>
                      <span
                        style={{
                          display: 'block',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {entry.activeValue ?? '—'}
                      </span>
                    </td>
                    <td>
                      <div
                        style={{
                          display: 'flex',
                          gap: 4,
                          flexWrap: 'wrap',
                        }}
                      >
                        {[...(scopedMap.get(entry.key) ?? [])].map(
                          (code) => (
                            <ScopeBadge
                              key={code}
                              code={code}
                              label={
                                scopes.find((scope) => scope.code === code)
                                  ?.label ?? code
                              }
                            />
                          ),
                        )}
                      </div>
                    </td>
                    <td>
                      {entry.isActive ? (
                        <ActiveBadge />
                      ) : (
                        <span className="admin-badge">INACTIVE</span>
                      )}
                    </td>
                    <td className="mono">
                      {formatDateTime(entry.activeSince)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ================================================================== */}
      {/* CONFIGURATION DETAIL DRAWER                                        */}
      {/* ================================================================== */}

      {selected && (
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Configuration Detail —{' '}
              <span className="mono">{selected.key}</span>
            </span>

            <button
              type="button"
              className="admin-page-btn"
              onClick={() => setSelected(null)}
              aria-label="Close configuration detail"
            >
              Close
            </button>
          </div>

          <div className="admin-kv">
            <span className="k">Key</span>
            <span className="v mono">{selected.key}</span>

            <span className="k">Name</span>
            <span className="v">{selected.name}</span>

            <span className="k">Description</span>
            <span className="v">
              {selected.description ?? '—'}
            </span>

            <span className="k">Data type</span>
            <span className="v">
              <span className="admin-badge">{selected.dataType}</span>
            </span>

            <span className="k">Default value</span>
            <span className="v mono">{selected.defaultValue ?? '—'}</span>

            <span className="k">Status</span>
            <span className="v">
              {selected.isActive ? <ActiveBadge /> : (
                <span className="admin-badge">INACTIVE</span>
              )}
            </span>
          </div>

          {selected.versions.length > 0 && (
            <>
              <div className="admin-panel-title" style={{ margin: '16px 0 8px' }}>
                Versions
              </div>

              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Version</th>
                      <th>Value</th>
                      <th>Created</th>
                      <th>Created by</th>
                    </tr>
                  </thead>

                  <tbody>
                    {selected.versions.map((version) => (
                      <tr key={version.id}>
                        <td className="mono">v{version.version}</td>
                        <td className="mono" style={{ maxWidth: 320 }}>
                          <span
                            style={{
                              display: 'block',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                              whiteSpace: 'nowrap',
                            }}
                          >
                            {version.value}
                          </span>
                        </td>
                        <td className="mono">
                          {formatDateTime(version.createdAt)}
                        </td>
                        <td className="mono">
                          {version.createdBy ?? '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}

          {selected.activations.length > 0 && (
            <>
              <div className="admin-panel-title" style={{ margin: '16px 0 8px' }}>
                Activations
              </div>

              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Scope</th>
                      <th>Entity</th>
                      <th>Activated</th>
                      <th>Activated by</th>
                    </tr>
                  </thead>

                  <tbody>
                    {selected.activations.map((activation) => (
                      <tr key={activation.id}>
                        <td className="mono">
                          {activation.scopeCode ?? '—'}
                        </td>
                        <td className="mono">
                          {activation.scopeEntityId ?? '—'}
                        </td>
                        <td className="mono">
                          {formatDateTime(activation.activatedAt)}
                        </td>
                        <td className="mono">
                          {activation.activatedBy ?? '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
}