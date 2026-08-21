// =============================================================================
// src/components/History/ChiefComplaintPanel.tsx
//
// AMEXAN — CHIEF COMPLAINT / PRESENTING ITEM CAPTURE
//
// CORE RULE:
// -----------------------------------------------------------------------------
// LOCAL STATE -> UI -> LIVE DOCUMENTATION -> PERSISTENCE -> HPI
//
// There is ONE source of truth: `items`.
//
// The component NEVER creates a second representation of the current CC set
// for documentation. Everything visible to the clinician is derived from the
// same current state.
//
// IMPORTANT:
// - Default duration unit = DAYS.
// - Maximum 4 presenting items.
// - Every item has its own stable ID.
// - Vocabulary code is NOT the React key.
// - Existing rows remain editable after adding more rows.
// - Existing rows use "Change", never a plus button.
// - Patient wording is independent from canonical vocabulary.
// - Chronology = oldest -> most recent.
// - Live documentation updates immediately from local state.
// - Persistence is serialized and revision-aware.
// - A stale save can never mark a newer edit as saved.
// - HPI receives the exact same chronological snapshot.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import type { ClinicalFact } from '../../clinical/types';

import {
  type ComplaintDefinition,
  type DurationUnit,
  COMPLAINT_SYSTEM_LABELS,
  DURATION_UNIT_LABELS,
  DURATION_UNITS,
  MAX_CHIEF_COMPLAINTS,
  MIN_CHIEF_COMPLAINTS,
  complaintByCode,
  durationToSeconds,
  formatDuration,
  getChiefComplaintEntries,
  searchComplaints,
  sentenceCase,
} from '../../clinical/complaints';

import {
  CrossIcon,
  SearchIcon,
  CheckIcon,
} from '../Icons';

// =============================================================================
// TYPES
// =============================================================================

export type PresentingItemType =
  | 'complaint'
  | 'free-text'
  | 'no-chief-complaint'
  | 'follow-up'
  | 'general-check-up';

export interface ChiefComplaintRecord {
  id: string;

  type: PresentingItemType;

  code: string | null;

  canonicalLabel: string | null;

  patientWording: string;

  durationValue: string;

  durationUnit: DurationUnit;

  sequence: number;
}

interface ChiefComplaintPanelProps {
  facts: ClinicalFact[];

  /**
   * MUST resolve only after the complete current CC set has actually been
   * persisted successfully.
   */
  onSave: (
    complaints: ChiefComplaintRecord[],
  ) => Promise<void> | void;

  /**
   * Receives the exact same chronological snapshot used by this component.
   */
  onContinue?: (
    complaints: ChiefComplaintRecord[],
  ) => void;
}

// =============================================================================
// CONFIGURATION
// =============================================================================

const DEFAULT_DURATION_UNIT: DurationUnit =
  'days';

const MAX_ITEMS = Math.min(
  MAX_CHIEF_COMPLAINTS,
  4,
);

const MIN_ITEMS = Math.max(
  MIN_CHIEF_COMPLAINTS,
  1,
);

// =============================================================================
// SPECIAL PRESENTING ITEMS
// =============================================================================

const SPECIAL_PRESENTING_ITEMS: Array<{
  type: PresentingItemType;
  code: string;
  label: string;
}> = [
  {
    type: 'no-chief-complaint',
    code: 'NO_CHIEF_COMPLAINT',
    label: 'No chief complaint',
  },
  {
    type: 'follow-up',
    code: 'FOLLOW_UP',
    label: 'Follow-up',
  },
  {
    type: 'general-check-up',
    code: 'GENERAL_CHECK_UP',
    label: 'General check-up',
  },
];

// =============================================================================
// ID
// =============================================================================

function createId(): string {
  if (
    typeof crypto !== 'undefined' &&
    typeof crypto.randomUUID === 'function'
  ) {
    return crypto.randomUUID();
  }

  return `cc-${Date.now()}-${Math.random()
    .toString(36)
    .slice(2, 10)}`;
}

// =============================================================================
// DURATION
// =============================================================================

function secondsOf(
  item: ChiefComplaintRecord,
): number {
  const value = Number(
    item.durationValue,
  );

  if (
    !Number.isFinite(value) ||
    value <= 0 ||
    !DURATION_UNITS.includes(
      item.durationUnit,
    )
  ) {
    return 0;
  }

  return durationToSeconds(
    value,
    item.durationUnit,
  );
}

function hasValidDuration(
  item: ChiefComplaintRecord,
): boolean {
  const raw =
    item.durationValue.trim();

  if (!raw) {
    return false;
  }

  const value = Number(raw);

  return (
    Number.isFinite(value) &&
    value > 0 &&
    DURATION_UNITS.includes(
      item.durationUnit,
    )
  );
}

// =============================================================================
// DURATION SHORTHAND
//
// 4/7   -> 4 days
// 3/52  -> 3 weeks
// 2/12  -> 2 months
// 6/24  -> 6 hours
// 2/365 -> 2 years
// =============================================================================

const SHORTHAND_DENOMINATOR_TO_UNIT: Record<
  string,
  DurationUnit
> = {
  '7': 'days',
  '52': 'weeks',
  '12': 'months',
  '24': 'hours',
  '365': 'years',
};

function parseShorthandDuration(
  raw: string,
): {
  value: string;
  unit: DurationUnit;
} | null {
  const trimmed =
    raw.trim();

  if (!trimmed.includes('/')) {
    return null;
  }

  const parts =
    trimmed.split('/');

  if (parts.length !== 2) {
    return null;
  }

  const value = Number(
    parts[0].trim(),
  );

  if (
    !Number.isFinite(value) ||
    value <= 0
  ) {
    return null;
  }

  const unit =
    SHORTHAND_DENOMINATOR_TO_UNIT[
      parts[1].trim()
    ];

  if (!unit) {
    return null;
  }

  return {
    value: String(value),
    unit,
  };
}

// =============================================================================
// HYDRATION
// =============================================================================

function hydrateFromFacts(
  facts: ClinicalFact[],
): ChiefComplaintRecord[] {
  const entries =
    getChiefComplaintEntries(
      facts,
    );

  return entries.map(
    (entry, index) => ({
      id: createId(),

      type: 'complaint',

      code: entry.code,

      canonicalLabel:
        entry.label,

      patientWording:
        entry.label,

      durationValue:
        entry.durationSeconds > 0
          ? String(
              entry.durationValue || '',
            )
          : '',

      // IMPORTANT:
      // Existing persisted records keep their actual unit.
      // New records default to DAYS.
      durationUnit:
        entry.durationUnit ||
        DEFAULT_DURATION_UNIT,

      sequence: index,
    }),
  );
}

// =============================================================================
// ORDERING
//
// Longest duration = oldest.
// Shortest duration = most recent.
//
// Incomplete items stay at the end.
// Equal durations retain insertion order.
// =============================================================================

function orderItems(
  items: ChiefComplaintRecord[],
): ChiefComplaintRecord[] {
  return [...items].sort(
    (a, b) => {
      const aSeconds =
        secondsOf(a);

      const bSeconds =
        secondsOf(b);

      const aIncomplete =
        aSeconds <= 0;

      const bIncomplete =
        bSeconds <= 0;

      if (
        aIncomplete &&
        bIncomplete
      ) {
        return (
          a.sequence -
          b.sequence
        );
      }

      if (aIncomplete) {
        return 1;
      }

      if (bIncomplete) {
        return -1;
      }

      if (
        aSeconds ===
        bSeconds
      ) {
        return (
          a.sequence -
          b.sequence
        );
      }

      return (
        bSeconds -
        aSeconds
      );
    },
  );
}

// =============================================================================
// SPECIAL RECORD
// =============================================================================

function createSpecialRecord(
  type: PresentingItemType,
  sequence: number,
): ChiefComplaintRecord | null {
  const option =
    SPECIAL_PRESENTING_ITEMS.find(
      (item) =>
        item.type === type,
    );

  if (!option) {
    return null;
  }

  return {
    id: createId(),

    type,

    code: option.code,

    canonicalLabel:
      option.label,

    patientWording:
      option.label,

    durationValue: '',

    durationUnit:
      DEFAULT_DURATION_UNIT,

    sequence,
  };
}

// =============================================================================
// FREE TEXT
// =============================================================================

function createFreeTextRecord(
  wording: string,
  sequence: number,
): ChiefComplaintRecord | null {
  const clean =
    wording.trim();

  if (!clean) {
    return null;
  }

  return {
    id: createId(),

    type: 'free-text',

    code: null,

    canonicalLabel: null,

    patientWording: clean,

    durationValue: '',

    durationUnit:
      DEFAULT_DURATION_UNIT,

    sequence,
  };
}

// =============================================================================
// COMPONENT
// =============================================================================

export function ChiefComplaintPanel({
  facts,
  onSave,
  onContinue,
}: ChiefComplaintPanelProps) {
  // ===========================================================================
  // LOCAL STATE
  // ===========================================================================

  const [
    items,
    setItems,
  ] = useState<
    ChiefComplaintRecord[]
  >([]);

  const [
    query,
    setQuery,
  ] = useState('');

  const [
    searchOpen,
    setSearchOpen,
  ] = useState(false);

  const [
    dirty,
    setDirty,
  ] = useState(false);

  const [
    saving,
    setSaving,
  ] = useState(false);

  const [
    savedRevision,
    setSavedRevision,
  ] = useState(0);

  const [
    revision,
    setRevision,
  ] = useState(0);

  const [
    activeId,
    setActiveId,
  ] = useState<string | null>(
    null,
  );

  // ===========================================================================
  // REFS
  // ===========================================================================

  const hydratedRef =
    useRef(false);

  const latestRevisionRef =
    useRef(0);

  const savingRef =
    useRef(false);

  const queuedSaveRef =
    useRef<ChiefComplaintRecord[] | null>(
      null,
    );

  const searchRef =
    useRef<HTMLInputElement>(
      null,
    );

  const wordingRefs =
    useRef<
      Record<
        string,
        HTMLInputElement | null
      >
    >({});

  const durationRefs =
    useRef<
      Record<
        string,
        HTMLInputElement | null
      >
    >({});

  // ===========================================================================
  // INITIAL HYDRATION
  // ===========================================================================
  //
  // ONLY ONCE.
  //
  // A parent facts refresh must not wipe the clinician's active editing state.
  // ===========================================================================

  const initial =
    useMemo(
      () =>
        hydrateFromFacts(
          facts,
        ),
      [facts],
    );

  useEffect(() => {
    if (hydratedRef.current) {
      return;
    }

    hydratedRef.current =
      true;

    setItems(initial);

    setDirty(false);

    setSavedRevision(
      initial.length > 0
        ? 0
        : -1,
    );

    setRevision(0);

    setActiveId(
      initial.length > 0
        ? initial[
            initial.length - 1
          ]?.id ?? null
        : null,
    );
  }, [initial]);

  // ===========================================================================
  // ORDERED ITEMS
  // ===========================================================================

  const ordered =
    useMemo(
      () =>
        orderItems(items),
      [items],
    );

  // ===========================================================================
  // SELECTED CODES
  // ===========================================================================

  const selectedCodes =
    useMemo(
      () =>
        new Set(
          items
            .map(
              (item) =>
                item.code,
            )
            .filter(
              (
                code,
              ): code is string =>
                Boolean(code),
            ),
        ),
      [items],
    );

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  const suggestions =
    useMemo(() => {
      const clean =
        query.trim();

      if (!clean) {
        return [];
      }

      return searchComplaints(
        clean,
      );
    }, [query]);

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  const durationsComplete =
    items.length > 0 &&
    items.every(
      hasValidDuration,
    );

  const canAdd =
    items.length <
    MAX_ITEMS;

  const canSave =
    items.length >=
      MIN_ITEMS &&
    durationsComplete;

  const incompleteItems =
    useMemo(
      () =>
        items.filter(
          (item) =>
            !hasValidDuration(
              item,
            ),
        ),
      [items],
    );

  // ===========================================================================
  // MARK CHANGED
  //
  // Every edit increments a revision.
  //
  // This revision is the key to preventing an old database write from
  // incorrectly declaring a newer UI state as saved.
  // ===========================================================================

  const markChanged =
    useCallback(() => {
      setDirty(true);

      setSavedRevision(
        -1,
      );

      setRevision(
        (previous) => {
          const next =
            previous + 1;

          latestRevisionRef.current =
            next;

          return next;
        },
      );

      setHasSavedSafe(false);
    }, []);

  // ===========================================================================
  // SAVED STATE HELPER
  // ===========================================================================

  function setHasSavedSafe(
    value: boolean,
  ) {
    if (value) {
      // The UI derives "saved" from revision equality.
      return;
    }

    // Intentionally no independent saved boolean.
    // `savedRevision === revision` is the source of truth.
  }

  const isSaved =
    !dirty &&
    revision >= 0 &&
    savedRevision ===
      revision;

  // ===========================================================================
  // PAYLOAD
  // ===========================================================================

  const buildPayload =
    useCallback(
      () =>
        orderItems(
          items,
        ).map(
          (item) => ({
            ...item,

            patientWording:
              item.patientWording.trim(),

            durationValue:
              item.durationValue.trim(),
          }),
        ),
      [items],
    );

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  const updateItem =
    useCallback(
      (
        id: string,
        patch: Partial<
          ChiefComplaintRecord
        >,
      ) => {
        let nextPatch = patch;

        if (
          typeof patch.durationValue ===
          'string'
        ) {
          const shorthand =
            parseShorthandDuration(
              patch.durationValue,
            );

          if (shorthand) {
            nextPatch = {
              ...patch,
              durationValue:
                shorthand.value,
              durationUnit:
                shorthand.unit,
            };
          }
        }

        setItems(
          (previous) =>
            previous.map(
              (item) =>
                item.id === id
                  ? {
                      ...item,
                      ...nextPatch,
                    }
                  : item,
            ),
        );

        setActiveId(id);

        markChanged();
      },
      [markChanged],
    );

  // ===========================================================================
  // ADD STRUCTURED COMPLAINT
  // ===========================================================================

  const addComplaint =
    useCallback(
      (
        definition: ComplaintDefinition,
      ) => {
        if (!canAdd) {
          return;
        }

        if (
          selectedCodes.has(
            definition.code,
          )
        ) {
          return;
        }

        const newItem: ChiefComplaintRecord =
          {
            id: createId(),

            type: 'complaint',

            code:
              definition.code,

            canonicalLabel:
              definition.label,

            patientWording:
              definition.label,

            durationValue: '',

            // DEFAULT = DAYS
            durationUnit:
              DEFAULT_DURATION_UNIT,

            sequence:
              items.length,
          };

        setItems(
          (previous) => [
            ...previous,
            newItem,
          ],
        );

        setActiveId(
          newItem.id,
        );

        markChanged();

        setQuery('');
        setSearchOpen(false);

        window.setTimeout(
          () => {
            wordingRefs.current[
              newItem.id
            ]?.focus();
          },
          0,
        );
      },
      [
        canAdd,
        selectedCodes,
        items.length,
        markChanged,
      ],
    );

  // ===========================================================================
  // ADD SPECIAL ITEM
  // ===========================================================================

  const addSpecialItem =
    useCallback(
      (
        type: PresentingItemType,
      ) => {
        if (!canAdd) {
          return;
        }

        if (
          items.some(
            (item) =>
              item.type === type,
          )
        ) {
          return;
        }

        const newItem =
          createSpecialRecord(
            type,
            items.length,
          );

        if (!newItem) {
          return;
        }

        setItems(
          (previous) => [
            ...previous,
            newItem,
          ],
        );

        setActiveId(
          newItem.id,
        );

        markChanged();

        window.setTimeout(
          () => {
            durationRefs.current[
              newItem.id
            ]?.focus();
          },
          0,
        );
      },
      [
        canAdd,
        items,
        markChanged,
      ],
    );

  // ===========================================================================
  // ADD FREE TEXT
  // ===========================================================================

  const addFreeText =
    useCallback(() => {
      if (!canAdd) {
        return;
      }

      const newItem =
        createFreeTextRecord(
          query,
          items.length,
        );

      if (!newItem) {
        return;
      }

      setItems(
        (previous) => [
          ...previous,
          newItem,
        ],
      );

      setActiveId(
        newItem.id,
      );

      markChanged();

      setQuery('');
      setSearchOpen(false);

      window.setTimeout(
        () => {
          durationRefs.current[
            newItem.id
          ]?.focus();
        },
        0,
      );
    }, [
      canAdd,
      query,
      items.length,
      markChanged,
    ]);

  // ===========================================================================
  // REMOVE
  // ===========================================================================

  const removeItem =
    useCallback(
      (id: string) => {
        setItems(
          (previous) =>
            previous.filter(
              (item) =>
                item.id !== id,
            ),
        );

        markChanged();

        setActiveId(
          (previous) =>
            previous === id
              ? null
              : previous,
        );
      },
      [markChanged],
    );

  // ===========================================================================
  // SAVE QUEUE
  //
  // Saves are serialized.
  //
  // If the user changes:
  //
  // A -> B -> C
  //
  // an older save cannot overwrite C and then tell the UI that C is saved.
  // ===========================================================================

  const persistSnapshot =
    useCallback(
      async (
        snapshot: ChiefComplaintRecord[],
        snapshotRevision: number,
      ) => {
        if (
          savingRef.current
        ) {
          queuedSaveRef.current =
            snapshot;

          return false;
        }

        savingRef.current =
          true;

        setSaving(true);

        try {
          await onSave(
            snapshot,
          );

          // Only mark the UI clean if this save corresponds to the latest
          // revision.
          if (
            latestRevisionRef.current ===
            snapshotRevision
          ) {
            setSavedRevision(
              snapshotRevision,
            );

            setDirty(false);
          }

          return true;
        } catch (error) {
          console.error(
            'AMEXAN: Chief complaint persistence failed.',
            error,
          );

          return false;
        } finally {
          savingRef.current =
            false;

          setSaving(false);

          // If another edit occurred while the database was being written,
          // immediately persist the latest state.
          if (
            queuedSaveRef.current
          ) {
            const queued =
              queuedSaveRef.current;

            queuedSaveRef.current =
              null;

            const queuedRevision =
              latestRevisionRef.current;

            void persistSnapshot(
              queued,
              queuedRevision,
            );
          }
        }
      },
      [onSave],
    );

  // ===========================================================================
  // REALTIME AUTO-PERSIST
  //
  // A short debounce prevents a database write on every single keystroke while
  // still making documentation persistence effectively immediate.
  //
  // The UI/live documentation itself updates synchronously on every keystroke.
  // ===========================================================================

  const autoSaveTimer =
    useRef<
      ReturnType<typeof setTimeout> | null
    >(null);

  useEffect(() => {
    if (
      !hydratedRef.current ||
      !dirty ||
      !canSave
    ) {
      return;
    }

    if (
      autoSaveTimer.current
    ) {
      clearTimeout(
        autoSaveTimer.current,
      );
    }

    const snapshot =
      buildPayload();

    const snapshotRevision =
      latestRevisionRef.current;

    autoSaveTimer.current =
      setTimeout(() => {
        void persistSnapshot(
          snapshot,
          snapshotRevision,
        );
      }, 180);

    return () => {
      if (
        autoSaveTimer.current
      ) {
        clearTimeout(
          autoSaveTimer.current,
        );

        autoSaveTimer.current =
          null;
      }
    };
  }, [
    dirty,
    canSave,
    buildPayload,
    persistSnapshot,
  ]);

  // ===========================================================================
  // CLEANUP
  // ===========================================================================

  useEffect(() => {
    return () => {
      if (
        autoSaveTimer.current
      ) {
        clearTimeout(
          autoSaveTimer.current,
        );
      }
    };
  }, []);

  // ===========================================================================
  // EXPLICIT SAVE
  // ===========================================================================

  const handleSave =
    useCallback(async () => {
      const snapshot =
        buildPayload();

      const currentRevision =
        latestRevisionRef.current;

      if (
        !canSave ||
        snapshot.length === 0
      ) {
        return;
      }

      await persistSnapshot(
        snapshot,
        currentRevision,
      );
    }, [
      buildPayload,
      canSave,
      persistSnapshot,
    ]);

  // ===========================================================================
  // CONTINUE TO HPI
  // ===========================================================================

  const handleContinue =
    useCallback(async () => {
      if (
        !onContinue ||
        !canSave
      ) {
        return;
      }

      const snapshot =
        buildPayload();

      const currentRevision =
        latestRevisionRef.current;

      // Ensure latest state is persisted first.
      if (
        dirty
      ) {
        const success =
          await persistSnapshot(
            snapshot,
            currentRevision,
          );

        if (!success) {
          return;
        }
      }

      onContinue(
        snapshot,
      );
    }, [
      onContinue,
      canSave,
      buildPayload,
      dirty,
      persistSnapshot,
    ]);

  // ===========================================================================
  // SEARCH KEYBOARD
  // ===========================================================================

  const handleSearchKeyDown =
    (
      event: React.KeyboardEvent<HTMLInputElement>,
    ) => {
      if (
        event.key === 'Enter'
      ) {
        event.preventDefault();

        if (
          suggestions.length >
          0
        ) {
          addComplaint(
            suggestions[0],
          );

          return;
        }

        if (
          query.trim()
        ) {
          addFreeText();
        }

        return;
      }

      if (
        event.key === 'Escape'
      ) {
        setSearchOpen(false);
      }
    };

  // ===========================================================================
  // LIVE DOCUMENTATION
  //
  // IMPORTANT:
  // This is generated DIRECTLY from `ordered`.
  //
  // Therefore:
  //
  // edit duration -> documentation changes immediately
  // edit wording  -> documentation changes immediately
  // add CC        -> documentation changes immediately
  // remove CC     -> documentation changes immediately
  // reorder       -> documentation changes immediately
  //
  // There is no second state object to become stale.
  // ===========================================================================

  const liveDocumentation =
    useMemo(() => {
      return ordered.map(
        (item) => {
          const wording =
            item.patientWording.trim();

          const durationValid =
            hasValidDuration(
              item,
            );

          const durationText =
            durationValid
              ? formatDuration(
                  Number(
                    item.durationValue,
                  ),
                  item.durationUnit,
                )
              : '';

          if (
            item.type ===
            'no-chief-complaint'
          ) {
            return 'No chief complaint.';
          }

          if (
            item.type ===
            'follow-up'
          ) {
            return durationValid
              ? `Follow-up for ${durationText}.`
              : 'Follow-up.';
          }

          if (
            item.type ===
            'general-check-up'
          ) {
            return durationValid
              ? `General check-up for ${durationText}.`
              : 'General check-up.';
          }

          const display =
            wording ||
            item.canonicalLabel ||
            'Unspecified complaint';

          if (!durationValid) {
            return `${sentenceCase(display)}.`;
          }

          return `${sentenceCase(display)} for ${durationText}.`;
        },
      );
    }, [ordered]);

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <section
      className="w-full min-w-0 bg-white border border-line-strong rounded-card shadow-card"
      aria-labelledby="chief-complaint-title"
    >
      {/* =====================================================================
          HEADER
          ===================================================================== */}

      <header className="flex items-start justify-between gap-3 px-3.5 py-3 border-b border-line bg-gradient-to-b from-white to-panel-alt max-[700px]:flex-col max-[700px]:items-start max-[700px]:gap-[7px] max-[700px]:px-3 max-[700px]:py-[11px] max-[340px]:px-[9px]">
        <div className="min-w-0">
          <h3
            id="chief-complaint-title"
            className="m-0 text-[0.95rem] leading-tight font-bold text-brand-2 max-[430px]:text-[0.9rem]"
          >
            Chief Complaint
          </h3>

          <p className="mt-[3px] mb-0 max-w-[720px] text-[11px] leading-[1.45] text-muted max-[430px]:text-[10.5px]">
            Record the patient's
            presenting complaints,
            reason for visit, or
            own wording.
          </p>
        </div>

        <div className="flex flex-col items-end gap-1 min-w-0 shrink-0 max-[700px]:w-full max-[700px]:flex-row max-[700px]:items-center max-[700px]:justify-between">
          <span className="badge info">
            {items.length}/{MAX_ITEMS}
          </span>

          {saving && (
            <span className="inline-flex items-center gap-1 shrink-0 text-[11px] leading-[1.3] font-semibold text-warn">
              Recording…
            </span>
          )}

          {!saving &&
            isSaved && (
              <span className="inline-flex items-center gap-1 shrink-0 text-[11px] leading-[1.3] font-semibold text-good">
                <CheckIcon size={14} />
                Recorded
              </span>
            )}

          {!saving &&
            dirty &&
            !isSaved && (
              <span className="inline-flex items-center gap-1 shrink-0 text-[11px] leading-[1.3] font-semibold text-brand-2">
                Updating…
              </span>
            )}
        </div>
      </header>

      {/* =====================================================================
          ADD AREA
          ===================================================================== */}

      {canAdd && (
        <div className="relative z-30 px-3.5 pt-3 max-[340px]:px-[9px]">
          <div className="flex flex-col gap-0.5 min-w-0 mb-2">
            <div>
              <strong className="text-xs leading-[1.3] font-bold text-ink">
                Add presenting item
              </strong>

              <span className="text-[11px] leading-[1.3] text-muted">
                Search the clinical
                vocabulary or enter
                the patient's own
                words.
              </span>
            </div>
          </div>

          <div className="relative flex items-center w-full min-w-0">
            <span
              className="absolute left-[11px] top-1/2 -translate-y-1/2 inline-flex items-center justify-center text-muted pointer-events-none"
              aria-hidden="true"
            >
              <SearchIcon size={17} />
            </span>

            <input
              ref={searchRef}
              type="text"
              className="w-full min-w-0 min-h-10 py-[9px] pr-[38px] pl-[35px] border border-line-strong rounded-field bg-white text-ink text-[13px] leading-[1.35] font-sans placeholder:text-muted/80 transition-colors duration-100 hover:border-brand focus:outline-none focus:border-brand focus:ring-[3px] focus:ring-brand/15 max-[430px]:min-h-[42px] max-[430px]:pl-[34px]"
              placeholder="Search complaint or enter patient's own words"
              value={query}
              autoComplete="off"
              onChange={(
                event,
              ) => {
                setQuery(
                  event.target
                    .value,
                );

                setSearchOpen(
                  true,
                );
              }}
              onFocus={() =>
                setSearchOpen(
                  true,
                )
              }
              onBlur={() =>
                window.setTimeout(
                  () =>
                    setSearchOpen(
                      false,
                    ),
                  180,
                )
              }
              onKeyDown={
                handleSearchKeyDown
              }
            />

            {query.trim() && (
              <button
                type="button"
                className="absolute right-[7px] top-1/2 -translate-y-1/2 inline-flex items-center justify-center w-[26px] h-[26px] p-0 border-0 rounded-[7px] bg-brand-light text-muted cursor-pointer transition-colors duration-100 hover:text-brand-2 hover:bg-line-strong focus-visible:outline-2 focus-visible:outline-brand focus-visible:outline-offset-2"
                aria-label="Clear search"
                onMouseDown={(
                  event,
                ) =>
                  event.preventDefault()
                }
                onClick={() => {
                  setQuery('');
                  setSearchOpen(
                    true,
                  );
                  searchRef.current?.focus();
                }}
              >
                <CrossIcon size={14} />
              </button>
            )}
          </div>

          {/* SEARCH RESULTS */}

          {searchOpen &&
            query.trim() && (
              <div
                className="z-[100] mx-3.5 mt-1.5 max-h-[min(320px,45vh)] overflow-x-hidden overflow-y-auto p-1 border border-line-strong rounded-[10px] bg-white shadow-pop overscroll-contain"
                role="listbox"
              >
                {suggestions.map(
                  (
                    suggestion,
                  ) => {
                    const already =
                      selectedCodes.has(
                        suggestion.code,
                      );

                    return (
                      <button
                        key={
                          suggestion.code
                        }
                        type="button"
                        className="flex items-center justify-between w-full min-w-0 min-h-10 gap-2.5 px-2.5 py-2 border-0 rounded-lg bg-transparent text-left cursor-pointer transition-colors duration-100 hover:bg-brand-light focus-visible:bg-brand-light focus-visible:outline-2 focus-visible:outline-brand focus-visible:-outline-offset-2 disabled:opacity-45 disabled:cursor-not-allowed max-[430px]:min-h-[42px]"
                        disabled={
                          already
                        }
                        onMouseDown={(
                          event,
                        ) =>
                          event.preventDefault()
                        }
                        onClick={() =>
                          addComplaint(
                            suggestion,
                          )
                        }
                      >
                        <span className="flex items-center gap-2 min-w-0">
                          <span className="min-w-0 truncate text-[13px] leading-[1.35] font-semibold text-ink">
                            {
                              suggestion.label
                            }
                          </span>

                          {already && (
                            <span className="shrink-0 px-[7px] py-0.5 rounded-full bg-brand-light text-brand-2 text-[10px] leading-[1.2] font-bold uppercase tracking-[0.03em] whitespace-nowrap">
                              selected
                            </span>
                          )}
                        </span>

                        <span className="shrink-0 max-w-[30%] truncate text-[11px] leading-[1.3] text-muted whitespace-nowrap max-[430px]:hidden">
                          {
                            COMPLAINT_SYSTEM_LABELS[
                              suggestion
                                .system
                            ]
                          }
                        </span>
                      </button>
                    );
                  },
                )}

                {/* FREE TEXT */}

                <button
                  type="button"
                  className="flex items-center justify-between w-full min-w-0 min-h-10 gap-2.5 px-2.5 py-2 border-t border-line rounded-b-lg bg-transparent text-left cursor-pointer transition-colors duration-100 hover:bg-brand-light focus-visible:bg-brand-light focus-visible:outline-2 focus-visible:outline-brand focus-visible:-outline-offset-2 max-[430px]:min-h-[42px]"
                  onMouseDown={(
                    event,
                  ) =>
                    event.preventDefault()
                  }
                  onClick={
                    addFreeText
                  }
                >
                  <span className="flex items-center gap-2 min-w-0">
                    <span className="min-w-0 truncate text-[13px] leading-[1.35] font-semibold text-ink">
                      Use patient's own
                      wording
                    </span>

                    <span className="shrink-0 px-[7px] py-0.5 rounded-full bg-brand-light text-brand-2 text-[10px] leading-[1.2] font-bold uppercase tracking-[0.03em] whitespace-nowrap">
                      "{query.trim()}"
                    </span>
                  </span>

                  <span className="shrink-0 max-w-[30%] truncate text-[11px] leading-[1.3] text-muted whitespace-nowrap max-[430px]:hidden">
                    Free text
                  </span>
                </button>
              </div>
            )}

          {/* QUICK PRESENTING ITEMS */}

          <div className="flex items-center gap-2 mt-2.5 py-[9px] px-2.5 min-w-0 border border-dashed border-line-strong rounded-[10px] bg-[#fbfcff]">
            <span className="shrink-0 text-[10.5px] leading-[1.3] font-bold uppercase tracking-[0.04em] text-muted">
              Other presenting
              reasons
            </span>

            <div className="flex items-center flex-wrap gap-1.5 min-w-0">
              {SPECIAL_PRESENTING_ITEMS.map(
                (option) => {
                  const selected =
                    items.some(
                      (item) =>
                        item.type ===
                        option.type,
                    );

                  return (
                    <button
                      key={
                        option.type
                      }
                      type="button"
                      className={`px-2.5 py-1 rounded-full text-[11px] leading-[1.2] font-semibold transition-colors duration-100 hover:border-brand hover:bg-brand-light hover:text-brand focus-visible:outline-2 focus-visible:outline-brand focus-visible:outline-offset-2 disabled:cursor-not-allowed ${
                        selected
                          ? 'border-good/45 bg-good/10 text-good opacity-85'
                          : 'border border-line-strong bg-white text-brand-2'
                      }`}
                      disabled={
                        selected
                      }
                      onClick={() =>
                        addSpecialItem(
                          option.type,
                        )
                      }
                    >
                      {option.label}
                    </button>
                  );
                },
              )}
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          PRESENTING ITEMS TABLE
          ===================================================================== */}

      <div className="min-w-0 pt-3 px-3.5 pb-3.5 max-[340px]:px-[9px]">
        <div className="flex items-center justify-between gap-2.5 min-w-0 mb-2">
          <div className="flex items-center flex-wrap gap-2 min-w-0">
            <span className="text-[11px] leading-[1.25] font-bold uppercase tracking-[0.05em] text-muted">
              Patient's presenting items
            </span>

            {ordered.length >
              1 && (
              <span className="shrink-0 text-[11px] leading-[1.25] text-brand-2">
                Oldest → most recent
              </span>
            )}
          </div>

          <span className="inline-flex items-center justify-center shrink-0 min-w-[22px] h-[22px] px-[7px] border border-line-strong rounded-full bg-brand-light text-brand-2 text-[11px] leading-none font-bold">
            {ordered.length}
          </span>
        </div>

        {ordered.length ===
        0 ? (
          <div className="flex flex-col items-center text-center gap-1 px-3.5 py-[22px] border border-dashed border-line-strong rounded-[12px] bg-[#fbfcff] text-muted">
            <SearchIcon size={20} />

            <strong className="text-[13px] leading-[1.3] text-brand-2">
              No presenting item
              recorded
            </strong>

            <span className="text-[11.5px] leading-[1.4] text-muted">
              Search above to add
              the patient's reason
              for attendance.
            </span>
          </div>
        ) : (
          <div className="flex flex-col min-w-0 border border-line-strong rounded-[12px] overflow-hidden bg-white">
            {/* TABLE HEADER */}

            <div className="hidden grid-cols-[46px_minmax(110px,1fr)_minmax(130px,1.1fr)_minmax(140px,0.9fr)_92px] items-center gap-2.5 px-3 py-2 border-b border-line bg-panel-alt text-[10.5px] leading-[1.25] font-bold uppercase tracking-[0.05em] text-muted max-[900px]:grid-cols-[42px_minmax(100px,1fr)_minmax(120px,1fr)_minmax(130px,0.9fr)_84px] max-[900px]:gap-2 max-[900px]:px-2.5 max-[700px]:hidden">
              <span>#</span>
              <span>Complaint</span>
              <span>
                Patient's wording
              </span>
              <span>
                Duration
              </span>
              <span>Action</span>
            </div>

            {/* TABLE ROWS */}

            {ordered.map(
              (
                item,
                index,
              ) => {
                const valid =
                  hasValidDuration(
                    item,
                  );

                const definition =
                  item.code
                    ? complaintByCode(
                        item.code,
                      )
                    : null;

                const active =
                  activeId ===
                  item.id;

                return (
                  <article
                    key={item.id}
                    className={[
                      'grid grid-cols-[46px_minmax(110px,1fr)_minmax(130px,1.1fr)_minmax(140px,0.9fr)_92px] items-center gap-2.5 px-3 py-2.5 border-b border-line bg-white transition-colors duration-100 hover:bg-[#fbfcff] last:border-b-0 max-[900px]:grid-cols-[42px_minmax(100px,1fr)_minmax(120px,1fr)_minmax(130px,0.9fr)_84px] max-[900px]:gap-2 max-[900px]:px-2.5 max-[700px]:flex max-[700px]:flex-col max-[700px]:items-stretch max-[700px]:gap-2 max-[700px]:p-2.5',
                      active
                        ? 'bg-brand-light/45 shadow-[inset_3px_0_0_var(--color-brand)]'
                        : '',
                      !valid
                        ? 'bg-warn/10'
                        : '',
                    ]
                      .filter(
                        Boolean,
                      )
                      .join(' ')}
                  >
                    {/* POSITION */}

                    <div className="flex flex-col items-center gap-0.5 min-w-0 max-[700px]:flex-row max-[700px]:items-center max-[700px]:justify-between">
                      <span className="inline-flex items-center justify-center w-[25px] h-[25px] border border-line-strong rounded-full bg-brand-light text-brand-2 text-xs leading-none font-bold">
                        {index + 1}
                      </span>

                      {valid &&
                        index ===
                          0 &&
                        ordered.length >
                          1 && (
                          <small className="max-w-[46px] truncate text-[8px] leading-[1.15] font-bold uppercase tracking-[0.03em] text-brand text-center whitespace-nowrap">
                            Oldest
                          </small>
                        )}

                      {valid &&
                        index ===
                          ordered.length -
                            1 &&
                        ordered.length >
                          1 && (
                          <small className="max-w-[46px] truncate text-[8px] leading-[1.15] font-bold uppercase tracking-[0.03em] text-brand text-center whitespace-nowrap">
                            Most recent
                          </small>
                        )}
                    </div>

                    {/* COMPLAINT */}

                    <div className="flex flex-col gap-[3px] min-w-0">
                      <strong className="min-w-0 truncate text-[13px] leading-[1.35] font-bold text-ink whitespace-nowrap">
                        {item.canonicalLabel ||
                          item.patientWording}
                      </strong>

                      <small className="min-w-0 truncate text-[10.5px] leading-[1.3] text-muted whitespace-nowrap">
                        {item.type ===
                          'complaint' &&
                          'Complaint'}

                        {item.type ===
                          'free-text' &&
                          'Patient wording'}

                        {item.type ===
                          'follow-up' &&
                          'Reason for visit'}

                        {item.type ===
                          'general-check-up' &&
                          'Reason for visit'}

                        {item.type ===
                          'no-chief-complaint' &&
                          'Presenting status'}

                        {definition &&
                          ` • ${
                            COMPLAINT_SYSTEM_LABELS[
                              definition
                                .system
                            ]
                          }`}
                      </small>
                    </div>

                    {/* PATIENT WORDING */}

                    <div className="min-w-0">
                      <input
                        ref={(
                          element,
                        ) => {
                          wordingRefs.current[
                            item.id
                          ] =
                            element;
                        }}
                        type="text"
                        value={
                          item.patientWording
                        }
                        aria-label={`Patient wording for ${
                          item.canonicalLabel ||
                          item.patientWording
                        }`}
                        placeholder="Patient's own wording"
                        onFocus={() =>
                          setActiveId(
                            item.id,
                          )
                        }
                        onChange={(
                          event,
                        ) =>
                          updateItem(
                            item.id,
                            {
                              patientWording:
                                event
                                  .target
                                  .value,
                            },
                          )
                        }
                        className="w-full min-w-0 h-[34px] px-[9px] py-1.5 border border-line-strong rounded-lg bg-white text-ink text-[12.5px] leading-[1.2] placeholder:text-muted/80 transition-colors duration-100 hover:border-brand focus:outline-none focus:border-brand focus:ring-[3px] focus:ring-brand/15"
                      />
                    </div>

                    {/* DURATION */}

                    <div className="flex flex-col gap-1 min-w-0">
                      <div className="flex items-center gap-[5px] min-w-0">
                        <input
                          ref={(
                            element,
                          ) => {
                            durationRefs.current[
                              item.id
                            ] =
                              element;
                          }}
                          type="text"
                          inputMode="decimal"
                          value={
                            item.durationValue
                          }
                          placeholder="Value"
                          aria-label={`Duration for ${
                            item.canonicalLabel ||
                            item.patientWording
                          }`}
                          onFocus={() =>
                            setActiveId(
                              item.id,
                            )
                          }
                          onChange={(
                            event,
                          ) =>
                            updateItem(
                              item.id,
                              {
                                durationValue:
                                  event
                                    .target
                                    .value,
                              },
                            )
                          }
                          className="w-[62px] min-w-[54px] h-[34px] px-2 py-1.5 border border-line-strong rounded-lg bg-white text-ink text-[13px] leading-[1.2] tabular-nums transition-colors duration-100 hover:border-brand focus:outline-none focus:border-brand focus:ring-[3px] focus:ring-brand/15 max-[430px]:w-[58px] max-[430px]:min-w-[50px]"
                        />

                        <select
                          value={
                            item.durationUnit
                          }
                          aria-label="Duration unit"
                          onChange={(
                            event,
                          ) =>
                            updateItem(
                              item.id,
                              {
                                durationUnit:
                                  event
                                    .target
                                    .value as DurationUnit,
                              },
                            )
                          }
                          className="flex-1 min-w-0 h-[34px] py-1.5 pr-6 pl-2 border border-line-strong rounded-lg bg-white text-ink text-xs leading-[1.2] transition-colors duration-100 hover:border-brand focus:outline-none focus:border-brand focus:ring-[3px] focus:ring-brand/10"
                        >
                          {DURATION_UNITS.map(
                            (
                              unit,
                            ) => (
                              <option
                                key={
                                  unit
                                }
                                value={
                                  unit
                                }
                              >
                                {
                                  DURATION_UNIT_LABELS[
                                    unit
                                  ]
                                }
                              </option>
                            ),
                          )}
                        </select>
                      </div>

                      <small
                        className={
                          valid
                            ? 'text-[10.5px] leading-[1.3] font-semibold text-good'
                            : 'text-[10.5px] leading-[1.3] font-semibold text-warn'
                        }
                      >
                        {valid
                          ? formatDuration(
                              Number(
                                item.durationValue,
                              ),
                              item.durationUnit,
                            )
                          : 'Duration required'}
                      </small>
                    </div>

                    {/* ACTION */}

                    <div className="flex items-center justify-end gap-1 min-w-0">
                      <button
                        type="button"
                        className="h-[30px] px-2.5 border border-line-strong rounded-lg bg-white text-brand-2 text-[11.5px] leading-none font-semibold cursor-pointer whitespace-nowrap transition-colors duration-100 hover:border-brand hover:bg-brand-light hover:text-brand focus-visible:outline-2 focus-visible:outline-brand focus-visible:outline-offset-2"
                        onClick={() => {
                          setActiveId(
                            item.id,
                          );

                          window.setTimeout(
                            () => {
                              wordingRefs.current[
                                item.id
                              ]?.focus();
                            },
                            0,
                          );
                        }}
                      >
                        Change
                      </button>

                      <button
                        type="button"
                        className="inline-flex items-center justify-center w-[30px] h-[30px] p-0 border-0 rounded-lg bg-transparent text-muted cursor-pointer transition-colors duration-100 hover:bg-bad-bg hover:text-[#b91c1c] focus-visible:outline-2 focus-visible:outline-[#b91c1c] focus-visible:outline-offset-2"
                        aria-label={`Remove ${
                          item.patientWording
                        }`}
                        onClick={() =>
                          removeItem(
                            item.id,
                          )
                        }
                      >
                        <CrossIcon
                          size={14}
                        />
                      </button>
                    </div>
                  </article>
                );
              },
            )}
          </div>
        )}
      </div>

      {/* =====================================================================
          FACT SUMMARY
          ===================================================================== */}

      <div className="mx-3.5 mb-3 p-3 border border-line-strong rounded-[12px] bg-gradient-to-b from-white to-[#f8faff] max-[340px]:mx-[9px]">
        <div className="flex items-center justify-between gap-2.5 min-w-0 mb-2.5">
          <div className="flex flex-col gap-0.5 min-w-0">
            <strong className="text-xs leading-[1.3] font-bold text-ink">
              Clinical fact summary
            </strong>

            <span className="text-[11px] leading-[1.3] text-muted">
              Current structured
              presenting facts
            </span>
          </div>

          <span className="shrink-0 inline-flex items-center justify-center min-w-[22px] h-[22px] px-2 border border-line-strong rounded-full bg-brand-light text-brand-2 text-[11px] leading-none font-bold">
            {ordered.length}{' '}
            {ordered.length === 1
              ? 'item'
              : 'items'}
          </span>
        </div>

        <div className="grid grid-cols-[repeat(auto-fill,minmax(210px,1fr))] gap-2 min-w-0 max-[700px]:grid-cols-1">
          {ordered.map(
            (item, index) => {
              const valid =
                hasValidDuration(
                  item,
                );

              return (
                <div
                  key={item.id}
                  className="flex items-start gap-2 min-w-0 px-2.5 py-2 border border-line rounded-[10px] bg-white"
                >
                  <span className="shrink-0 inline-flex items-center justify-center w-5 h-5 border border-line-strong rounded-full bg-brand-light text-brand-2 text-[10.5px] leading-none font-bold">
                    {index + 1}
                  </span>

                  <div className="flex flex-col gap-0.5 min-w-0">
                    <strong className="min-w-0 truncate text-[12.5px] leading-[1.3] font-bold text-ink whitespace-nowrap">
                      {item.canonicalLabel ||
                        item.patientWording}
                    </strong>

                    <span className="min-w-0 truncate text-[10.5px] leading-[1.35] text-muted whitespace-nowrap">
                      Patient wording:{' '}
                      {item.patientWording ||
                        'Not specified'}
                    </span>

                    <span className="min-w-0 truncate text-[10.5px] leading-[1.35] text-muted whitespace-nowrap">
                      Duration:{' '}
                      {valid
                        ? formatDuration(
                            Number(
                              item.durationValue,
                            ),
                            item.durationUnit,
                          )
                        : 'Incomplete'}
                    </span>

                    {item.code && (
                      <span className="min-w-0 truncate text-[10.5px] leading-[1.35] text-muted whitespace-nowrap">
                        Code:{' '}
                        {item.code}
                      </span>
                    )}
                  </div>
                </div>
              );
            },
          )}
        </div>
      </div>

      {/* =====================================================================
          LIVE DOCUMENTATION
          ===================================================================== */}

      <section className="mx-3.5 mb-3 border border-line-strong rounded-[12px] overflow-hidden bg-white max-[340px]:mx-[9px]">
        <div className="flex items-center justify-between gap-2.5 min-w-0 px-3 py-2.5 border-b border-line bg-gradient-to-b from-[#f4f7ff] to-white">
          <div className="flex flex-col gap-0.5 min-w-0">
            <strong className="text-xs leading-[1.3] font-bold text-brand-2">
              Live Documentation
            </strong>

            <span className="text-[11px] leading-[1.3] text-muted">
              Written as the history
              is captured
            </span>
          </div>

          <span className="shrink-0 inline-flex items-center gap-1 px-[9px] py-[3px] border border-good/35 rounded-full bg-good/10 text-good text-[10.5px] leading-[1.2] font-bold">
            ● Live
          </span>
        </div>

        <div className="px-3 py-2.5">
          <div className="flex items-center gap-2 min-w-0 mb-1.5">
            <strong className="text-[11px] leading-[1.3] font-bold uppercase tracking-[0.05em] text-muted">
              Chief Complaint
            </strong>
          </div>

          {liveDocumentation.length ===
          0 ? (
            <p className="m-0 text-[11.5px] leading-[1.4] text-muted">
              No presenting complaint
              recorded.
            </p>
          ) : (
            <ol className="flex flex-col gap-1 min-w-0 m-0 pl-[18px]">
              {liveDocumentation.map(
                (
                  line,
                  index,
                ) => (
                  <li
                    key={
                      ordered[index]
                        ?.id ??
                      index
                    }
                    className="text-[12.5px] leading-[1.5] text-ink"
                  >
                    {line}
                  </li>
                ),
              )}
            </ol>
          )}
        </div>
      </section>

      {/* =====================================================================
          VALIDATION
          ===================================================================== */}

      {items.length >
        0 &&
        !durationsComplete && (
          <div
            className="flex flex-col gap-1.5 mx-3.5 mb-3 px-3 py-2.5 border border-warn/45 rounded-[10px] bg-warn/10 max-[340px]:mx-[9px]"
            role="status"
          >
            <strong className="text-xs leading-[1.3] font-bold text-warn">
              Complete the presenting
              items
            </strong>

            <span className="text-[11px] leading-[1.4] text-muted">
              Every selected complaint
              needs a duration before
              continuing to HPI.
            </span>

            <div className="flex flex-wrap gap-1.5">
              {incompleteItems.map(
                (item) => (
                  <button
                    key={item.id}
                    type="button"
                    className="px-2.5 py-1 border border-line-strong rounded-full bg-white text-[11px] leading-[1.2] font-semibold text-brand-2 cursor-pointer transition-colors duration-100 hover:border-brand hover:text-brand"
                    onClick={() => {
                      setActiveId(
                        item.id,
                      );

                      window.setTimeout(
                        () => {
                          durationRefs.current[
                            item.id
                          ]?.focus();
                        },
                        0,
                      );
                    }}
                  >
                    {item.patientWording ||
                      item.canonicalLabel}
                  </button>
                ),
              )}
            </div>
          </div>
        )}

      {/* =====================================================================
          FOOTER
          ===================================================================== */}

      <footer className="flex items-center justify-between gap-2.5 min-w-0 px-3.5 py-2.5 border-t border-line bg-gradient-to-b from-white to-[#f6f8ff] max-[700px]:flex-col max-[700px]:items-stretch max-[340px]:px-[9px]">
        <div className="min-w-0 text-[11px] leading-[1.4] text-muted max-[700px]:text-left">
          {items.length ===
            0 && (
            <span>
              Add the patient's
              presenting complaint
              to begin.
            </span>
          )}

          {items.length >
            0 &&
            !durationsComplete && (
              <span>
                Complete all durations.
              </span>
            )}

          {durationsComplete &&
            dirty &&
            !saving && (
            <span>
              Recording latest changes…
            </span>
          )}

          {saving && (
            <span>
              Recording…
            </span>
          )}

          {isSaved && (
            <span className="inline-flex items-center gap-1 text-[11px] leading-[1.3] font-semibold text-good">
              <CheckIcon size={14} />
              All changes recorded
            </span>
          )}
        </div>

        <div className="flex items-center shrink-0 gap-2 max-[700px]:w-full">
          <button
            type="button"
            className="btn-primary max-[700px]:flex-1"
            disabled={
              !canSave ||
              saving
            }
            onClick={
              handleSave
            }
          >
            {saving
              ? 'Recording…'
              : 'Save complaints'}
          </button>

          {onContinue && (
            <button
              type="button"
              className="btn-primary whitespace-nowrap max-[700px]:flex-1"
              disabled={
                !canSave ||
                saving
              }
              onClick={
                handleContinue
              }
            >
              Continue to HPI →
            </button>
          )}
        </div>
      </footer>
    </section>
  );
}