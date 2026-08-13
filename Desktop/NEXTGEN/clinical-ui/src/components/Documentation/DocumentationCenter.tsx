import type { DocumentationSection } from '../../types';

export function DocumentationCenter({ sections }: { sections: DocumentationSection[] }) {
  if (sections.length === 0) {
    return (
      <section className="card">
        <header className="card-header">
          <h2>Documentation</h2>
        </header>
        <p className="muted">Documentation is generated live from structured state.</p>
      </section>
    );
  }

  const totalFacts = sections.reduce((n, s) => n + s.sentences.length, 0);

  return (
    <section className="card">
      <header className="card-header">
        <h2>Live documentation</h2>
        <span className="muted small">provenance: generated from {totalFacts} structured sentences</span>
      </header>

      {sections.map((section) => (
        <div key={section.section} className="doc-section">
          <h3>{section.section}</h3>
          {section.sentences.length === 0 ? (
            <p className="muted small">Nothing yet.</p>
          ) : (
            section.sentences.map((s, i) => (
              <p key={i} className="doc-sentence">
                {s.text}
                {s.factCode && <span className="fact-tag">{s.factCode}</span>}
              </p>
            ))
          )}
        </div>
      ))}

      <div className="doc-provenance muted small">
        Every sentence carries its source fact tags. Clinician edits are never overwritten by the system.
      </div>
    </section>
  );
}