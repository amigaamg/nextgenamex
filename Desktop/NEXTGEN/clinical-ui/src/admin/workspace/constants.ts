// =============================================================================
// AMEXAN Admin Workspace — Navigation Registry
//
// The shell derives its complete navigation surface from this registry.
//
// DESIGN RULES
// -----------------------------------------------------------------------------
// 1. Navigation is defined in one place.
// 2. Every AdminView has one canonical title.
// 3. Every AdminMode has one canonical description.
// 4. Views can belong to multiple modes.
// 5. No view component should define its own navigation metadata.
// 6. The registry is intentionally declarative and side-effect free.
// 7. TypeScript must reject:
//      - unknown views
//      - unknown modes
//      - duplicate object keys
//      - incomplete VIEW_TITLES
//      - incomplete MODE_DESCRIPTIONS
// =============================================================================

import type {
  AdminMode,
  AdminView,
} from './types';

// =============================================================================
// NAVIGATION ITEM
// =============================================================================

export interface AdminNavItem {
  readonly view: AdminView;
  readonly label: string;
  readonly description: string;
}

// =============================================================================
// MODE NAVIGATION
// =============================================================================

export const MODE_NAV: Record<AdminMode, readonly AdminNavItem[]> = {
  // ===========================================================================
  // OPERATE
  // ===========================================================================
  OPERATE: [
    {
      view: 'command',
      label: 'Command Center',
      description: 'Live system operations',
    },
    {
      view: 'engines',
      label: 'Engine Monitor',
      description: 'Engine health and execution',
    },
    {
      view: 'safety',
      label: 'Safety Center',
      description: 'Clinical safety signals',
    },
    {
      view: 'runtime',
      label: 'Runtime',
      description: 'Runtime and workers',
    },
    {
      view: 'integrations',
      label: 'Integrations',
      description: 'External system health',
    },
    {
      view: 'notifications',
      label: 'Notifications',
      description: 'Operational notifications',
    },
    {
      view: 'catalogues',
      label: 'Service Catalogues',
      description: 'Facility service registry',
    },
    {
      view: 'assets',
      label: 'Asset Intelligence',
      description: 'Care continuity through asset intelligence',
    },
    {
      view: 'financial',
      label: 'Financial',
      description: 'Facility financial operating picture',
    },
    {
      view: 'research',
      label: 'Research Intelligence',
      description: 'Governed clinical research environment',
    },
  ],

  // ===========================================================================
  // INVESTIGATE
  // ===========================================================================
  INVESTIGATE: [
    {
      view: 'events',
      label: 'Event Explorer',
      description: 'What happened',
    },
    {
      view: 'trace',
      label: 'Encounter Trace',
      description: 'Patient/workflow trace',
    },
    {
      view: 'safety',
      label: 'Safety Center',
      description: 'Safety investigations',
    },
    {
      view: 'incidents',
      label: 'Incidents',
      description: 'Incident investigation',
    },
    {
      view: 'workflow',
      label: 'Workflow',
      description: 'Workflow execution',
    },
    {
      view: 'config',
      label: 'Configuration',
      description: 'Effective configuration',
    },
  ],

  // ===========================================================================
  // IMPROVE
  // ===========================================================================
  IMPROVE: [
    {
      view: 'config',
      label: 'Configuration',
      description: 'System configuration',
    },
    {
      view: 'versions',
      label: 'System Versions',
      description: 'Versions and compatibility',
    },
    {
      view: 'security',
      label: 'Security / RBAC',
      description: 'Access and governance',
    },
    {
      view: 'analytics',
      label: 'Analytics',
      description: 'System and product analytics',
    },
    {
      view: 'database',
      label: 'Database',
      description: 'Data layer health',
    },
    {
      view: 'engines',
      label: 'Engine Monitor',
      description: 'Engine performance',
    },
    {
      view: 'catalogues',
      label: 'Service Catalogues',
      description: 'Configure facility services',
    },
    {
      view: 'assets',
      label: 'Asset Intelligence',
      description: 'Configure facility asset resilience',
    },
  ],
};

// =============================================================================
// CANONICAL VIEW TITLES
// =============================================================================

export const VIEW_TITLES: Record<AdminView, string> = {
  command: 'Command Center',
  events: 'Event Explorer',
  trace: 'Encounter Trace',
  engines: 'Engine Monitor',
  safety: 'Safety Center',
  config: 'Configuration',
  versions: 'System Versions',
  security: 'Security / RBAC',
  database: 'Database',
  runtime: 'Runtime',
  workflow: 'Workflow',
  incidents: 'Incidents',
  integrations: 'Integrations',
  notifications: 'Notifications',
  analytics: 'Analytics',
  catalogues: 'Service Catalogues',
  assets: 'Asset Intelligence',
  financial: 'Financial',
  research: 'Research Intelligence',
};

// =============================================================================
// MODE DESCRIPTIONS
// =============================================================================

export const MODE_DESCRIPTIONS: Record<AdminMode, string> = {
  OPERATE: 'what is happening',
  INVESTIGATE: 'why did it happen',
  IMPROVE: 'what to change',
};

// =============================================================================
// HELPERS
// =============================================================================

/**
 * Return the navigation items available to a mode.
 *
 * A fresh array is returned so consumers cannot accidentally mutate the
 * canonical registry.
 */
export function getModeNavigation(
  mode: AdminMode,
): AdminNavItem[] {
  return [...MODE_NAV[mode]];
}

/**
 * Return the canonical title for an AdminView.
 */
export function getViewTitle(
  view: AdminView,
): string {
  return VIEW_TITLES[view];
}

/**
 * Return the canonical description for an AdminMode.
 */
export function getModeDescription(
  mode: AdminMode,
): string {
  return MODE_DESCRIPTIONS[mode];
}

/**
 * Determine whether a view is available in a given mode.
 */
export function isViewInMode(
  mode: AdminMode,
  view: AdminView,
): boolean {
  return MODE_NAV[mode].some(
    (item) => item.view === view,
  );
}

/**
 * Find the navigation definition for a view within a mode.
 */
export function findModeNavItem(
  mode: AdminMode,
  view: AdminView,
): AdminNavItem | undefined {
  return MODE_NAV[mode].find(
    (item) => item.view === view,
  );
}

/**
 * Find every mode in which a particular view is registered.
 */
export function getModesForView(
  view: AdminView,
): AdminMode[] {
  const modes: AdminMode[] = [];

  for (const mode of Object.keys(MODE_NAV) as AdminMode[]) {
    if (isViewInMode(mode, view)) {
      modes.push(mode);
    }
  }

  return modes;
}

/**
 * Return every registered navigation item across all modes.
 *
 * Duplicate views are intentionally preserved because the same view may have
 * different contextual descriptions depending on the operating mode.
 */
export function getAllNavigationItems(): AdminNavItem[] {
  return (Object.keys(MODE_NAV) as AdminMode[]).flatMap(
    (mode) => MODE_NAV[mode],
  );
}

// =============================================================================
// PUBLIC TYPES
// =============================================================================

export type {
  AdminView,
  AdminMode,
} from './types';