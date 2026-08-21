// =============================================================================
// AMEXAN Security Center — enterprise RBAC / authorization observatory.
//
// READ-ONLY / INVESTIGATE / OPERATE
//
// Covers:
//   • Permission registry
//   • Resource permission coverage
//   • Role registry
//   • API scopes
//   • User-role assignments
//   • Organization / facility / department scope
//   • Assignment validity
//   • Live refresh
//   • Client-side search/filtering
//   • Safe partial refresh handling
//   • Loading / stale / error states
//
// No mutation is performed by this view.
// All authorization data is read through the existing API layer.
// =============================================================================

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { getSecurityOverview } from '../api';
import type { SecurityOverview as SecurityOverviewData } from '../types';

// =============================================================================
// CONSTANTS
// =============================================================================

const REFRESH_INTERVAL_MS = 15000;

type SecurityTab = 'resources' | 'roles' | 'scopes' | 'assignments';

// =============================================================================
// HELPERS
// =============================================================================

function safeText(value: unknown, fallback = '—'): string {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }

  return String(value);
}

function formatDate(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleDateString();
}

function formatDateTime(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleString();
}

function isAssignmentCurrentlyValid(
  validFrom: string,
  validTo: string | null | undefined,
): boolean {
  const now = Date.now();

  const from = new Date(validFrom).getTime();

  if (Number.isNaN(from)) {
    return false;
  }

  if (now < from) {
    return false;
  }

  if (!validTo) {
    return true;
  }

  const to = new Date(validTo).getTime();

  if (Number.isNaN(to)) {
    return false;
  }

  return now <= to;
}

function roleBadge(isSystem: boolean): string {
  return isSystem ? 'admin-badge brand' : 'admin-badge';
}

// =============================================================================
// STATUS INDICATOR
// =============================================================================

function LiveStatus({
  refreshing,
  lastUpdated,
  error,
}: {
  refreshing: boolean;
  lastUpdated: number | null;
  error: string | null;
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        flexWrap: 'wrap',
      }}
    >
      <span
        className={`admin-badge ${
          error ? 'bad' : refreshing ? 'warn' : 'ok'
        }`}
      >
        <span
          aria-hidden="true"
          style={{
            display: 'inline-block',
            width: 7,
            height: 7,
            borderRadius: '50%',
            marginRight: 6,
            background:
              error
                ? 'currentColor'
                : refreshing
                  ? 'currentColor'
                  : 'currentColor',
          }}
        />
        {error ? 'DEGRADED' : refreshing ? 'REFRESHING' : 'LIVE'}
      </span>

      <span className="muted small mono">
        {lastUpdated
          ? `updated ${formatDateTime(new Date(lastUpdated).toISOString())}`
          : 'awaiting first update'}
      </span>
    </div>
  );
}

// =============================================================================
// RESOURCE COVERAGE
// =============================================================================

function ResourceCoverage({
  resources,
}: {
  resources: SecurityOverviewData['resources'];
}) {
  const maxResource = Math.max(
    1,
    ...resources.map((resource) => resource.permissions),
  );

  const sortedResources = useMemo(
    () =>
      resources
        .slice()
        .sort((a, b) => b.permissions - a.permissions),
    [resources],
  );

  return (
    <div className="admin-panel">
      <div className="admin-panel-head">
        <span className="admin-panel-title">Resource Coverage</span>
        <span className="admin-panel-sub">
          {resources.length} resources · permissions by resource
        </span>
      </div>

      {sortedResources.length === 0 ? (
        <div className="admin-empty">
          No permissions registered.
        </div>
      ) : (
        <div>
          {sortedResources.map((resource) => {
            const percentage = Math.min(
              100,
              Math.round(
                (resource.permissions / maxResource) * 100,
              ),
            );

            return (
              <div
                key={resource.resource}
                className="admin-resource-bar"
              >
                <span
                  className="res-label"
                  title={resource.resource}
                >
                  {resource.resource}
                </span>

                <span className="res-count num">
                  {resource.permissions}
                </span>

                <span className="admin-resource-track">
                  <span
                    className="admin-resource-fill"
                    style={{
                      width: `${percentage}%`,
                    }}
                  />
                </span>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// =============================================================================
// ROLES
// =============================================================================

function RolesPanel({
  roles,
  search,
}: {
  roles: SecurityOverviewData['roles'];
  search: string;
}) {
  const filteredRoles = useMemo(() => {
    const query = search.trim().toLowerCase();

    if (!query) return roles;

    return roles.filter((role) =>
      [
        role.code,
        role.name,
        role.isSystem ? 'system' : '',
        String(role.permissionCount),
      ]
        .join(' ')
        .toLowerCase()
        .includes(query),
    );
  }, [roles, search]);

  return (
    <div className="admin-panel">
      <div className="admin-panel-head">
        <span className="admin-panel-title">Roles</span>
        <span className="admin-panel-sub">
          {filteredRoles.length} of {roles.length} registered
        </span>
      </div>

      {filteredRoles.length === 0 ? (
        <div className="admin-empty">
          No roles match the current search.
        </div>
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Code</th>
                <th>Name</th>
                <th>Permissions</th>
                <th>System</th>
              </tr>
            </thead>

            <tbody>
              {filteredRoles.map((role) => (
                <tr key={role.id}>
                  <td className="mono">
                    {safeText(role.code)}
                  </td>

                  <td>
                    {safeText(role.name)}
                  </td>

                  <td className="num">
                    {role.permissionCount}
                  </td>

                  <td>
                    {role.isSystem ? (
                      <span className={roleBadge(true)}>
                        SYSTEM
                      </span>
                    ) : (
                      <span className="muted">custom</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// =============================================================================
// API SCOPES
// =============================================================================

function ApiScopesPanel({
  scopes,
  search,
}: {
  scopes: SecurityOverviewData['apiScopes'];
  search: string;
}) {
  const filteredScopes = useMemo(() => {
    const query = search.trim().toLowerCase();

    if (!query) return scopes;

    return scopes.filter((scope) =>
      [scope.code, scope.label]
        .join(' ')
        .toLowerCase()
        .includes(query),
    );
  }, [scopes, search]);

  return (
    <div className="admin-panel">
      <div className="admin-panel-head">
        <span className="admin-panel-title">API Scopes</span>
        <span className="admin-panel-sub">
          {filteredScopes.length} of {scopes.length} registered
        </span>
      </div>

      {filteredScopes.length === 0 ? (
        <div className="admin-empty">
          No API scopes match the current search.
        </div>
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Code</th>
                <th>Label</th>
              </tr>
            </thead>

            <tbody>
              {filteredScopes.map((scope) => (
                <tr key={scope.code}>
                  <td className="mono">
                    {safeText(scope.code)}
                  </td>

                  <td>
                    {safeText(scope.label)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// =============================================================================
// ROLE ASSIGNMENTS
// =============================================================================

function AssignmentsPanel({
  assignments,
  search,
}: {
  assignments: SecurityOverviewData['assignments'];
  search: string;
}) {
  const filteredAssignments = useMemo(() => {
    const query = search.trim().toLowerCase();

    if (!query) return assignments;

    return assignments.filter((assignment) =>
      [
        assignment.username,
        assignment.userId,
        assignment.roleCode,
        assignment.roleId,
        assignment.organizationId,
        assignment.facilityId,
        assignment.departmentId,
      ]
        .map((value) => safeText(value, ''))
        .join(' ')
        .toLowerCase()
        .includes(query),
    );
  }, [assignments, search]);

  return (
    <div className="admin-panel">
      <div className="admin-panel-head">
        <span className="admin-panel-title">
          Role Assignments
        </span>

        <span className="admin-panel-sub">
          security.user_role · {filteredAssignments.length} of{' '}
          {assignments.length} shown
        </span>
      </div>

      {filteredAssignments.length === 0 ? (
        <div className="admin-empty">
          No role assignments match the current search.
        </div>
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Role</th>
                <th>Organization</th>
                <th>Facility</th>
                <th>Department</th>
                <th>Valid From</th>
                <th>Valid To</th>
                <th>State</th>
              </tr>
            </thead>

            <tbody>
              {filteredAssignments.map((assignment) => {
                const valid = isAssignmentCurrentlyValid(
                  assignment.validFrom,
                  assignment.validTo,
                );

                return (
                  <tr key={assignment.id}>
                    <td className="mono">
                      {safeText(
                        assignment.username ??
                          assignment.userId,
                      )}
                    </td>

                    <td className="mono">
                      {safeText(
                        assignment.roleCode ??
                          assignment.roleId,
                      )}
                    </td>

                    <td className="mono">
                      {safeText(
                        assignment.organizationId,
                      )}
                    </td>

                    <td className="mono">
                      {safeText(assignment.facilityId)}
                    </td>

                    <td className="mono">
                      {safeText(assignment.departmentId)}
                    </td>

                    <td className="mono">
                      {formatDate(assignment.validFrom)}
                    </td>

                    <td className="mono">
                      {formatDate(assignment.validTo)}
                    </td>

                    <td>
                      <span
                        className={`admin-badge ${
                          valid ? 'ok' : 'warn'
                        }`}
                      >
                        {valid ? 'VALID' : 'OUT OF WINDOW'}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// =============================================================================
// SECURITY VIEW
// =============================================================================

export function SecurityView() {
  const [data, setData] =
    useState<SecurityOverviewData | null>(null);

  const [loading, setLoading] = useState(true);

  const [refreshing, setRefreshing] = useState(false);

  const [error, setError] =
    useState<string | null>(null);

  const [search, setSearch] = useState('');

  const [activeTab, setActiveTab] =
    useState<SecurityTab>('resources');

  const [lastUpdated, setLastUpdated] =
    useState<number | null>(null);

  const mountedRef = useRef(true);

  // ---------------------------------------------------------------------------
  // LOAD
  // ---------------------------------------------------------------------------

  const load = useCallback(async (background = false) => {
    if (!background) {
      setLoading(true);
    } else {
      setRefreshing(true);
    }

    try {
      const next = await getSecurityOverview();

      if (!mountedRef.current) return;

      setData(next);
      setError(null);
      setLastUpdated(Date.now());
    } catch (e) {
      if (!mountedRef.current) return;

      const message =
        e instanceof Error
          ? e.message
          : 'Failed to load security overview';

      setError(message);
    } finally {
      if (!mountedRef.current) return;

      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  // ---------------------------------------------------------------------------
  // INITIAL LOAD + REALTIME-STYLE POLLING
  // ---------------------------------------------------------------------------

  useEffect(() => {
    mountedRef.current = true;

    void load(false);

    const timer = window.setInterval(() => {
      void load(true);
    }, REFRESH_INTERVAL_MS);

    const handleVisibility = () => {
      if (
        document.visibilityState === 'visible' &&
        mountedRef.current
      ) {
        void load(true);
      }
    };

    document.addEventListener(
      'visibilitychange',
      handleVisibility,
    );

    return () => {
      mountedRef.current = false;
      window.clearInterval(timer);

      document.removeEventListener(
        'visibilitychange',
        handleVisibility,
      );
    };
  }, [load]);

  // ---------------------------------------------------------------------------
  // INITIAL LOADING
  // ---------------------------------------------------------------------------

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Loading security center…
      </div>
    );
  }

  // ---------------------------------------------------------------------------
  // COMPLETE FAILURE
  // ---------------------------------------------------------------------------

  if (error && !data) {
    return (
      <div>
        <div className="admin-error">
          {error}
        </div>

        <button
          type="button"
          className="admin-page-btn"
          style={{ marginTop: 12 }}
          onClick={() => void load(false)}
        >
          Retry
        </button>
      </div>
    );
  }

  // ---------------------------------------------------------------------------
  // SAFE DEFAULTS
  // ---------------------------------------------------------------------------

  const summary = data?.summary;

  const resources =
    data?.resources ?? [];

  const roles =
    data?.roles ?? [];

  const scopes =
    data?.apiScopes ?? [];

  const assignments =
    data?.assignments ?? [];

  // ---------------------------------------------------------------------------
  // DERIVED SECURITY COUNTS
  // ---------------------------------------------------------------------------

  const validAssignments = assignments.filter(
    (assignment) =>
      isAssignmentCurrentlyValid(
        assignment.validFrom,
        assignment.validTo,
      ),
  ).length;

  const expiredAssignments =
    assignments.length - validAssignments;

  // ---------------------------------------------------------------------------
  // RENDER
  // ---------------------------------------------------------------------------

  return (
    <div>
      {/* =====================================================================
          HEADER / LIVE STATUS
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginBottom: 16 }}
      >
        <div
          className="admin-panel-head"
          style={{
            alignItems: 'center',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <div style={{ flex: 1, minWidth: 220 }}>
            <span className="admin-panel-title">
              Security Center
            </span>

            <span className="admin-panel-sub">
              AMEXAN authorization registry · RBAC · API scopes ·
              scoped assignments
            </span>
          </div>

          <LiveStatus
            refreshing={refreshing}
            lastUpdated={lastUpdated}
            error={error}
          />

          <button
            type="button"
            className="admin-page-btn"
            onClick={() => void load(true)}
            disabled={refreshing}
            title="Refresh security data"
          >
            {refreshing ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>

        {error && data && (
          <div
            className="admin-error"
            style={{ marginTop: 12 }}
          >
            Security data could not be refreshed completely.
            Existing data remains displayed.
            <span className="mono">
              {' '}
              {error}
            </span>
          </div>
        )}
      </div>

      {/* =====================================================================
          SECURITY SUMMARY
          ===================================================================== */}

      <div className="admin-tile-grid">
        <div className="admin-tile tile-brand">
          <span className="tile-label">
            Permissions
          </span>

          <span className="tile-value">
            {summary?.permissions ?? 0}
          </span>

          <span className="tile-note">
            atomic permission codes
          </span>
        </div>

        <div className="admin-tile">
          <span className="tile-label">
            Roles
          </span>

          <span className="tile-value">
            {summary?.roles ?? roles.length}
          </span>

          <span className="tile-note">
            permission bundles
          </span>
        </div>

        <div className="admin-tile">
          <span className="tile-label">
            API Scopes
          </span>

          <span className="tile-value">
            {summary?.apiScopes ?? scopes.length}
          </span>

          <span className="tile-note">
            registered API scopes
          </span>
        </div>

        <div className="admin-tile">
          <span className="tile-label">
            Assignments
          </span>

          <span className="tile-value">
            {summary?.assignments ??
              assignments.length}
          </span>

          <span className="tile-note">
            user-role assignments
          </span>
        </div>

        <div className="admin-tile tile-good">
          <span className="tile-label">
            Valid Assignments
          </span>

          <span className="tile-value">
            {validAssignments}
          </span>

          <span className="tile-note">
            currently within validity window
          </span>
        </div>

        <div className="admin-tile tile-warn">
          <span className="tile-label">
            Outside Validity
          </span>

          <span className="tile-value">
            {expiredAssignments}
          </span>

          <span className="tile-note">
            expired or not yet active
          </span>
        </div>
      </div>

      {/* =====================================================================
          SEARCH + TABS
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div
          className="admin-filters"
          style={{
            alignItems: 'center',
            flexWrap: 'wrap',
          }}
        >
          <input
            type="search"
            className="admin-input"
            style={{
              minWidth: 240,
              flex: 1,
            }}
            value={search}
            onChange={(event) =>
              setSearch(event.target.value)
            }
            placeholder="Search roles, scopes, users, resources…"
            aria-label="Search security registry"
          />

          {search && (
            <button
              type="button"
              className="admin-page-btn"
              onClick={() => setSearch('')}
            >
              Clear
            </button>
          )}
        </div>

        <div
          style={{
            display: 'flex',
            gap: 8,
            flexWrap: 'wrap',
            marginTop: 12,
          }}
          role="tablist"
          aria-label="Security registry sections"
        >
          <button
            type="button"
            role="tab"
            aria-selected={
              activeTab === 'resources'
            }
            className={
              activeTab === 'resources'
                ? 'admin-page-btn active'
                : 'admin-page-btn'
            }
            onClick={() =>
              setActiveTab('resources')
            }
          >
            Resources ({resources.length})
          </button>

          <button
            type="button"
            role="tab"
            aria-selected={
              activeTab === 'roles'
            }
            className={
              activeTab === 'roles'
                ? 'admin-page-btn active'
                : 'admin-page-btn'
            }
            onClick={() =>
              setActiveTab('roles')
            }
          >
            Roles ({roles.length})
          </button>

          <button
            type="button"
            role="tab"
            aria-selected={
              activeTab === 'scopes'
            }
            className={
              activeTab === 'scopes'
                ? 'admin-page-btn active'
                : 'admin-page-btn'
            }
            onClick={() =>
              setActiveTab('scopes')
            }
          >
            API Scopes ({scopes.length})
          </button>

          <button
            type="button"
            role="tab"
            aria-selected={
              activeTab === 'assignments'
            }
            className={
              activeTab === 'assignments'
                ? 'admin-page-btn active'
                : 'admin-page-btn'
            }
            onClick={() =>
              setActiveTab('assignments')
            }
          >
            Assignments ({assignments.length})
          </button>
        </div>
      </div>

      {/* =====================================================================
          REGISTRY CONTENT
          ===================================================================== */}

      <div style={{ marginTop: 16 }}>
        {activeTab === 'resources' && (
          <ResourceCoverage
            resources={resources}
          />
        )}

        {activeTab === 'roles' && (
          <RolesPanel
            roles={roles}
            search={search}
          />
        )}

        {activeTab === 'scopes' && (
          <ApiScopesPanel
            scopes={scopes}
            search={search}
          />
        )}

        {activeTab === 'assignments' && (
          <AssignmentsPanel
            assignments={assignments}
            search={search}
          />
        )}
      </div>

      {/* =====================================================================
          SECURITY OVERVIEW GRID
          ===================================================================== */}

      <div
        className="admin-grid-3"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Authorization Model
            </span>

            <span className="admin-panel-sub">
              current registry
            </span>
          </div>

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Permissions</td>
                <td className="num">
                  {summary?.permissions ??
                    resources.reduce(
                      (sum, resource) =>
                        sum + resource.permissions,
                      0,
                    )}
                </td>
              </tr>

              <tr>
                <td>Roles</td>
                <td className="num">
                  {roles.length}
                </td>
              </tr>

              <tr>
                <td>System roles</td>
                <td className="num">
                  {
                    roles.filter(
                      (role) => role.isSystem,
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Custom roles</td>
                <td className="num">
                  {
                    roles.filter(
                      (role) => !role.isSystem,
                    ).length
                  }
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Scope Coverage
            </span>

            <span className="admin-panel-sub">
              API authorization surface
            </span>
          </div>

          <table className="admin-table">
            <tbody>
              <tr>
                <td>API scopes</td>
                <td className="num">
                  {scopes.length}
                </td>
              </tr>

              <tr>
                <td>Role assignments</td>
                <td className="num">
                  {assignments.length}
                </td>
              </tr>

              <tr>
                <td>Valid assignments</td>
                <td className="num">
                  {validAssignments}
                </td>
              </tr>

              <tr>
                <td>Outside validity</td>
                <td className="num">
                  {expiredAssignments}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Scoped Access
            </span>

            <span className="admin-panel-sub">
              assignment boundaries
            </span>
          </div>

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Organization scoped</td>
                <td className="num">
                  {
                    assignments.filter(
                      (assignment) =>
                        Boolean(
                          assignment.organizationId,
                        ),
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Facility scoped</td>
                <td className="num">
                  {
                    assignments.filter(
                      (assignment) =>
                        Boolean(
                          assignment.facilityId,
                        ),
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Department scoped</td>
                <td className="num">
                  {
                    assignments.filter(
                      (assignment) =>
                        Boolean(
                          assignment.departmentId,
                        ),
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Unscoped assignments</td>
                <td className="num">
                  {
                    assignments.filter(
                      (assignment) =>
                        !assignment.organizationId &&
                        !assignment.facilityId &&
                        !assignment.departmentId,
                    ).length
                  }
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          FULL ASSIGNMENT VIEW
          ===================================================================== */}

      <div
        style={{ marginTop: 16 }}
      >
        <AssignmentsPanel
          assignments={assignments}
          search={search}
        />
      </div>
    </div>
  );
}