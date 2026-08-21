// =============================================================================
// AMEXAN Database — Control Plane Database Observatory
//
// OPERATE / IMPROVE
// Read-only.
// PostgreSQL is NEVER accessed directly from this component.
//
// Responsibilities:
//   • Database server health / identity
//   • PostgreSQL version visibility
//   • Database size / startup visibility
//   • Schema inventory
//   • Table inventory
//   • Migration registry
//   • Migration ordering / status visibility
//   • Search / filtering
//   • Refresh / stale-state visibility
//   • Safe display of database metadata
//
// Data flow:
//
//   PostgreSQL
//        │
//        ▼
//   Control Plane API
//        │
//        ▼
//   getDatabaseOverview()
//        │
//        ▼
//   DatabaseView
//        │
//        ├── Server
//        ├── Schema inventory
//        ├── Migration registry
//        └── Table inventory
//
// IMPORTANT:
// This view is intentionally read-only.
// No SQL, mutation, migration execution, DELETE, INSERT, UPDATE,
// ALTER, VACUUM, REINDEX or administrative database command is issued here.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ChangeEvent,
} from 'react';

import { getDatabaseOverview } from '../api';

import type {
  DatabaseOverview,
} from '../types';

type DatabaseSection =
  | 'overview'
  | 'migrations'
  | 'tables';

type HealthState =
  | 'good'
  | 'warn'
  | 'bad'
  | 'unknown';

const REFRESH_INTERVAL_MS = 30_000;

function safeString(value: unknown): string {
  if (value === null || value === undefined) {
    return '';
  }

  return String(value);
}

function displayValue(value: unknown, fallback = '—'): string {
  const result = safeString(value).trim();

  return result.length > 0 ? result : fallback;
}

function formatDate(
  value: unknown,
  fallback = '—',
): string {
  if (!value) {
    return fallback;
  }

  const date = new Date(String(value));

  if (Number.isNaN(date.getTime())) {
    return fallback;
  }

  return date.toLocaleString();
}

function formatRelativeTime(value: unknown): string {
  if (!value) {
    return '—';
  }

  const date = new Date(String(value));

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  const delta = Date.now() - date.getTime();

  if (delta < 0) {
    return 'in the future';
  }

  const seconds = Math.floor(delta / 1000);

  if (seconds < 10) {
    return 'just now';
  }

  if (seconds < 60) {
    return `${seconds}s ago`;
  }

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) {
    return `${minutes}m ago`;
  }

  const hours = Math.floor(minutes / 60);

  if (hours < 24) {
    return `${hours}h ago`;
  }

  const days = Math.floor(hours / 24);

  return `${days}d ago`;
}

function normalizeSearch(value: string): string {
  return value.trim().toLowerCase();
}

function includesSearch(
  values: unknown[],
  search: string,
): boolean {
  if (!search) {
    return true;
  }

  return values.some((value) =>
    safeString(value)
      .toLowerCase()
      .includes(search),
  );
}

function getHealthState(
  data: DatabaseOverview | null,
  error: string | null,
): HealthState {
  if (error && !data) {
    return 'bad';
  }

  if (!data) {
    return 'unknown';
  }

  return 'good';
}

function healthLabel(
  state: HealthState,
): string {
  switch (state) {
    case 'good':
      return 'Healthy';

    case 'warn':
      return 'Warning';

    case 'bad':
      return 'Degraded';

    default:
      return 'Unknown';
  }
}

export function DatabaseView() {
  const [data, setData] = useState<DatabaseOverview | null>(null);

  const [loading, setLoading] = useState(true);

  const [refreshing, setRefreshing] = useState(false);

  const [error, setError] = useState<string | null>(null);

  const [filter, setFilter] = useState('');

  const [section, setSection] =
    useState<DatabaseSection>('overview');

  const [lastSuccessfulRefresh, setLastSuccessfulRefresh] =
    useState<Date | null>(null);

  const load = useCallback(
    async (background = false) => {
      if (background) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }

      setError(null);

      try {
        const result = await getDatabaseOverview();

        setData(result);
        setLastSuccessfulRefresh(new Date());
      } catch (e) {
        const message =
          e instanceof Error
            ? e.message
            : 'Failed to load database overview';

        setError(message);
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [],
  );

  useEffect(() => {
    void load(false);

    const timer = window.setInterval(() => {
      void load(true);
    }, REFRESH_INTERVAL_MS);

    return () => {
      window.clearInterval(timer);
    };
  }, [load]);

  const handleRefresh = useCallback(() => {
    void load(true);
  }, [load]);

  const handleFilterChange = useCallback(
    (event: ChangeEvent<HTMLInputElement>) => {
      setFilter(event.target.value);
    },
    [],
  );

  const normalizedFilter = useMemo(
    () => normalizeSearch(filter),
    [filter],
  );

  const migrations = useMemo(() => {
    const source = data?.migrations ?? [];

    const filtered = source.filter((migration) =>
      includesSearch(
        [
          migration.version,
          migration.name,
          migration.appliedAt,
          migration.appliedBy,
        ],
        normalizedFilter,
      ),
    );

    return filtered
      .slice()
      .sort((a, b) => {
        const av = Number(a.version);
        const bv = Number(b.version);

        if (
          Number.isFinite(av) &&
          Number.isFinite(bv)
        ) {
          return bv - av;
        }

        return safeString(b.version).localeCompare(
          safeString(a.version),
        );
      });
  }, [data?.migrations, normalizedFilter]);

  const tables = useMemo(() => {
    const source = data?.tables ?? [];

    return source
      .filter((table) =>
        includesSearch(
          [
            table.schema,
            table.table,
          ],
          normalizedFilter,
        ),
      )
      .slice()
      .sort((a, b) => {
        const schemaCompare =
          safeString(a.schema).localeCompare(
            safeString(b.schema),
          );

        if (schemaCompare !== 0) {
          return schemaCompare;
        }

        return safeString(a.table).localeCompare(
          safeString(b.table),
        );
      });
  }, [data?.tables, normalizedFilter]);

  const schemaCounts = useMemo(() => {
    return (data?.schemaCounts ?? [])
      .slice()
      .sort((a, b) => {
        if (b.count !== a.count) {
          return b.count - a.count;
        }

        return safeString(a.schema).localeCompare(
          safeString(b.schema),
        );
      });
  }, [data?.schemaCounts]);

  const totalTables =
    data?.tables?.length ?? 0;

  const totalSchemas =
    data?.schemaCounts?.length ?? 0;

  const migrationCount =
    data?.migrationCount ??
    data?.migrations?.length ??
    0;

  const healthState = getHealthState(
    data,
    error,
  );

  const isInitialLoading =
    loading && !data;

  if (isInitialLoading) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Loading database observatory…
      </div>
    );
  }

  if (error && !data) {
    return (
      <div>
        <div
          className="admin-error"
          role="alert"
        >
          <strong>
            Database control-plane unavailable
          </strong>

          <div style={{ marginTop: 6 }}>
            {error}
          </div>

          <button
            type="button"
            className="admin-nav-btn"
            style={{ marginTop: 12 }}
            onClick={handleRefresh}
            disabled={refreshing}
          >
            {refreshing
              ? 'Retrying…'
              : 'Retry connection'}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* =====================================================================
          HEADER
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginBottom: 16 }}
      >
        <div
          className="admin-panel-head"
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 16,
            flexWrap: 'wrap',
          }}
        >
          <div>
            <div className="admin-panel-title">
              Database Observatory
            </div>

            <div className="admin-panel-sub">
              PostgreSQL server, schema, migration and
              table inventory
            </div>
          </div>

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              flexWrap: 'wrap',
            }}
          >
            <span
              className={`admin-health-dot ${healthState}`}
              aria-hidden="true"
            />

            <span>
              {healthLabel(healthState)}
            </span>

            <button
              type="button"
              className="admin-nav-btn"
              onClick={handleRefresh}
              disabled={refreshing}
              aria-label="Refresh database overview"
            >
              {refreshing
                ? 'Refreshing…'
                : 'Refresh'}
            </button>
          </div>
        </div>

        {error && data && (
          <div
            className="admin-error"
            role="status"
            style={{ marginTop: 12 }}
          >
            {error}
          </div>
        )}

        <div
          className="admin-activity-meta"
          style={{
            display: 'flex',
            gap: 18,
            flexWrap: 'wrap',
            marginTop: 12,
          }}
        >
          <span>
            <strong>
              {totalSchemas}
            </strong>{' '}
            schemas
          </span>

          <span>
            <strong>
              {totalTables}
            </strong>{' '}
            tables
          </span>

          <span>
            <strong>
              {migrationCount}
            </strong>{' '}
            migrations
          </span>

          <span className="muted small">
            Last successful refresh:{' '}
            {lastSuccessfulRefresh
              ? formatDate(
                  lastSuccessfulRefresh,
                )
              : '—'}
          </span>

          <span className="muted small">
            Auto-refresh: 30s
          </span>
        </div>
      </div>

      {/* =====================================================================
          SECTION NAVIGATION
          ===================================================================== */}

      <nav
        className="admin-nav"
        aria-label="Database sections"
        style={{ marginBottom: 16 }}
      >
        <button
          type="button"
          className={`admin-nav-btn${
            section === 'overview'
              ? ' active'
              : ''
          }`}
          onClick={() =>
            setSection('overview')
          }
        >
          Overview
        </button>

        <button
          type="button"
          className={`admin-nav-btn${
            section === 'migrations'
              ? ' active'
              : ''
          }`}
          onClick={() =>
            setSection('migrations')
          }
        >
          Migrations
          <span
            style={{
              marginLeft: 6,
              opacity: 0.7,
            }}
          >
            {migrationCount}
          </span>
        </button>

        <button
          type="button"
          className={`admin-nav-btn${
            section === 'tables'
              ? ' active'
              : ''
          }`}
          onClick={() =>
            setSection('tables')
          }
        >
          Tables
          <span
            style={{
              marginLeft: 6,
              opacity: 0.7,
            }}
          >
            {totalTables}
          </span>
        </button>
      </nav>

      {/* =====================================================================
          SEARCH
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginBottom: 16 }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <div
            style={{
              flex: '1 1 280px',
              minWidth: 0,
            }}
          >
            <label
              htmlFor="amexan-database-filter"
              className="admin-panel-sub"
              style={{
                display: 'block',
                marginBottom: 6,
              }}
            >
              Database inventory search
            </label>

            <input
              id="amexan-database-filter"
              type="search"
              className="admin-input"
              placeholder="Search migrations, schemas or tables…"
              value={filter}
              onChange={handleFilterChange}
              autoComplete="off"
              spellCheck={false}
            />
          </div>

          {filter && (
            <button
              type="button"
              className="admin-nav-btn"
              onClick={() => setFilter('')}
              style={{
                alignSelf: 'flex-end',
              }}
            >
              Clear
            </button>
          )}
        </div>

        {normalizedFilter && (
          <div
            className="muted small"
            style={{ marginTop: 8 }}
          >
            Showing filtered database inventory.
          </div>
        )}
      </div>

      {/* =====================================================================
          OVERVIEW
          ===================================================================== */}

      {section === 'overview' && (
        <div>
          <div className="admin-tile-grid">
            <div className="admin-tile">
              <span className="admin-tile-value">
                {totalSchemas}
              </span>

              <span className="admin-tile-label">
                Schemas
              </span>
            </div>

            <div className="admin-tile">
              <span className="admin-tile-value">
                {totalTables}
              </span>

              <span className="admin-tile-label">
                Tables
              </span>
            </div>

            <div className="admin-tile">
              <span className="admin-tile-value">
                {migrationCount}
              </span>

              <span className="admin-tile-label">
                Applied migrations
              </span>
            </div>

            <div className="admin-tile">
              <span className="admin-tile-value">
                {displayValue(
                  data?.server.size,
                )}
              </span>

              <span className="admin-tile-label">
                Database size
              </span>
            </div>
          </div>

          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >
            {/* ---------------------------------------------------------------
                SERVER
                --------------------------------------------------------------- */}

            <div className="admin-panel">
              <div className="admin-panel-head">
                <span className="admin-panel-title">
                  PostgreSQL Server
                </span>

                <span className="admin-panel-sub">
                  live database metadata
                </span>
              </div>

              <div className="admin-kv">
                <span className="k">
                  Database
                </span>

                <span className="v mono">
                  {displayValue(
                    data?.server.database,
                  )}
                </span>

                <span className="k">
                  User
                </span>

                <span className="v mono">
                  {displayValue(
                    data?.server.username,
                  )}
                </span>

                <span className="k">
                  Size
                </span>

                <span className="v">
                  {displayValue(
                    data?.server.size,
                  )}
                </span>

                <span className="k">
                  Started
                </span>

                <span className="v mono">
                  {formatDate(
                    data?.server.startedAt,
                  )}
                </span>

                <span className="k">
                  PostgreSQL
                </span>

                <span
                  className="v mono"
                  title={displayValue(
                    data?.server.version,
                  )}
                >
                  {displayValue(
                    data?.server.version,
                  )}
                </span>
              </div>
            </div>

            {/* ---------------------------------------------------------------
                DATABASE CONTROL-PLANE STATE
                --------------------------------------------------------------- */}

            <div className="admin-panel">
              <div className="admin-panel-head">
                <span className="admin-panel-title">
                  Control Plane State
                </span>

                <span className="admin-panel-sub">
                  metadata visibility
                </span>
              </div>

              <div className="admin-kv">
                <span className="k">
                  Connection state
                </span>

                <span className="v">
                  {healthLabel(
                    healthState,
                  )}
                </span>

                <span className="k">
                  Database
                </span>

                <span className="v mono">
                  {displayValue(
                    data?.server.database,
                  )}
                </span>

                <span className="k">
                  Schemas
                </span>

                <span className="v num">
                  {totalSchemas}
                </span>

                <span className="k">
                  Tables
                </span>

                <span className="v num">
                  {totalTables}
                </span>

                <span className="k">
                  Migrations
                </span>

                <span className="v num">
                  {migrationCount}
                </span>

                <span className="k">
                  Snapshot
                </span>

                <span className="v mono">
                  {lastSuccessfulRefresh
                    ? formatRelativeTime(
                        lastSuccessfulRefresh,
                      )
                    : '—'}
                </span>
              </div>
            </div>
          </div>

          {/* ---------------------------------------------------------------
              SCHEMA INVENTORY
              --------------------------------------------------------------- */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Schema Inventory
              </span>

              <span className="admin-panel-sub">
                {totalSchemas} schemas ·{' '}
                {totalTables} tables
              </span>
            </div>

            {schemaCounts.length === 0 ? (
              <div className="admin-empty">
                No schema inventory returned.
              </div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>
                        Schema
                      </th>

                      <th>
                        Tables
                      </th>

                      <th>
                        Share
                      </th>
                    </tr>
                  </thead>

                  <tbody>
                    {schemaCounts.map(
                      (entry) => {
                        const percentage =
                          totalTables > 0
                            ? Math.round(
                                (entry.count /
                                  totalTables) *
                                  100,
                              )
                            : 0;

                        return (
                          <tr
                            key={
                              entry.schema
                            }
                          >
                            <td className="mono">
                              {
                                entry.schema
                              }
                            </td>

                            <td className="num">
                              {
                                entry.count
                              }
                            </td>

                            <td
                              style={{
                                minWidth: 180,
                              }}
                            >
                              <div
                                style={{
                                  display:
                                    'flex',
                                  alignItems:
                                    'center',
                                  gap: 8,
                                }}
                              >
                                <div
                                  className="admin-bar-track"
                                  style={{
                                    flex: 1,
                                  }}
                                >
                                  <div
                                    className="admin-bar-fill"
                                    style={{
                                      width: `${percentage}%`,
                                    }}
                                  />
                                </div>

                                <span className="num">
                                  {
                                    percentage
                                  }
                                  %
                                </span>
                              </div>
                            </td>
                          </tr>
                        );
                      },
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* =====================================================================
          MIGRATIONS
          ===================================================================== */}

      {section === 'migrations' && (
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Migration Registry
            </span>

            <span className="admin-panel-sub">
              {migrations.length} visible ·{' '}
              {migrationCount} applied · newest first
            </span>
          </div>

          {migrations.length === 0 ? (
            <div className="admin-empty">
              {normalizedFilter
                ? 'No migrations match the current filter.'
                : 'No migration records returned.'}
            </div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>
                      Version
                    </th>

                    <th>
                      Migration
                    </th>

                    <th>
                      Applied
                    </th>

                    <th>
                      Relative
                    </th>

                    <th>
                      Applied by
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {migrations.map(
                    (migration) => (
                      <tr
                        key={`${safeString(
                          migration.version,
                        )}-${safeString(
                          migration.name,
                        )}`}
                      >
                        <td className="num">
                          #
                          {String(
                            migration.version,
                          ).padStart(
                            3,
                            '0',
                          )}
                        </td>

                        <td
                          className="mono"
                          style={{
                            maxWidth: 360,
                            wordBreak:
                              'break-word',
                          }}
                        >
                          {
                            migration.name
                          }
                        </td>

                        <td className="mono">
                          {formatDate(
                            migration.appliedAt,
                          )}
                        </td>

                        <td className="muted small">
                          {formatRelativeTime(
                            migration.appliedAt,
                          )}
                        </td>

                        <td className="mono">
                          {displayValue(
                            migration.appliedBy,
                          )}
                        </td>
                      </tr>
                    ),
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* =====================================================================
          TABLE INVENTORY
          ===================================================================== */}

      {section === 'tables' && (
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Table Inventory
            </span>

            <span className="admin-panel-sub">
              {tables.length} visible ·{' '}
              {totalTables} total
            </span>
          </div>

          {tables.length === 0 ? (
            <div className="admin-empty">
              {normalizedFilter
                ? 'No tables match the current filter.'
                : 'No table inventory returned.'}
            </div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>
                      #
                    </th>

                    <th>
                      Schema
                    </th>

                    <th>
                      Table
                    </th>

                    <th>
                      Qualified name
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {tables.map(
                    (table, index) => (
                      <tr
                        key={`${safeString(
                          table.schema,
                        )}.${safeString(
                          table.table,
                        )}`}
                      >
                        <td className="num">
                          {index + 1}
                        </td>

                        <td className="mono">
                          {
                            table.schema
                          }
                        </td>

                        <td className="mono">
                          {
                            table.table
                          }
                        </td>

                        <td className="mono muted">
                          {safeString(
                            table.schema,
                          )}
                          .
                          {safeString(
                            table.table,
                          )}
                        </td>
                      </tr>
                    ),
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* =====================================================================
          FOOTER STATUS
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{
          marginTop: 16,
          padding: '10px 16px',
        }}
      >
        <div
          className="admin-activity-meta"
          style={{
            display: 'flex',
            gap: 20,
            flexWrap: 'wrap',
            alignItems: 'center',
          }}
        >
          <span>
            <strong>
              {totalSchemas}
            </strong>{' '}
            schemas
          </span>

          <span>
            <strong>
              {totalTables}
            </strong>{' '}
            tables
          </span>

          <span>
            <strong>
              {migrationCount}
            </strong>{' '}
            migrations
          </span>

          <span>
            <strong>
              {data?.server.size ?? '—'}
            </strong>{' '}
            database size
          </span>

          <span
            className="muted small"
            style={{
              marginLeft: 'auto',
            }}
          >
            Control Plane · read-only ·
            PostgreSQL metadata projection
          </span>
        </div>
      </div>
    </div>
  );
}