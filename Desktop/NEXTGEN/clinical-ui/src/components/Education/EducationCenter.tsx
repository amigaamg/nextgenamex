import type { EducationItem } from '../../types';

export function EducationCenter({ education }: { education: EducationItem[] }) {
  if (education.length === 0) {
    return (
      <section className="card">
        <header className="card-header">
          <h2>Patient education</h2>
        </header>
        <p className="muted">No education materials recommended for the current state.</p>
      </section>
    );
  }
  return (
    <section className="card">
      <header className="card-header">
        <h2>Patient education</h2>
        <span className="muted small">{education.length} items</span>
      </header>
      <div className="edu-list">
        {education.map((e) => (
          <div key={e.educationCode} className="edu">
            <div className="edu-head">
              <span className="edu-title">{e.title}</span>
              <span className="tag">{e.audience}</span>
              <span className="muted small">{e.contentType}</span>
            </div>
            <p className="edu-body">{e.body}</p>
            <div className="muted small mono">{e.educationCode}</div>
          </div>
        ))}
      </div>
    </section>
  );
}