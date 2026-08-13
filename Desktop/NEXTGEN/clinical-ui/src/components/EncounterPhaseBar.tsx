export const PHASES = [
  { id: 'presentation', label: 'Presentation' },
  { id: 'history', label: 'History' },
  { id: 'exam', label: 'Examination' },
  { id: 'reasoning', label: 'Clinical reasoning' },
  { id: 'investigations', label: 'Investigations' },
  { id: 'management', label: 'Management' },
  { id: 'monitoring', label: 'Monitoring' },
] as const;

export function EncounterPhaseBar({
  phases,
  activePhase,
  onPhase,
}: {
  phases: readonly { id: string; label: string }[];
  activePhase: string;
  onPhase: (id: string) => void;
}) {
  const activeIndex = Math.max(0, phases.findIndex((p) => p.id === activePhase));
  return (
    <div className="phase-bar">
      <div className="phase-track">
        {phases.map((p, i) => {
          const state = i === activeIndex ? 'active' : i < activeIndex ? 'done' : 'pending';
          return (
            <button key={p.id} className={`phase ${state}`} onClick={() => onPhase(p.id)}>
              <span className="phase-dot">{state === 'done' ? '✓' : i + 1}</span>
              <span className="phase-label">{p.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
