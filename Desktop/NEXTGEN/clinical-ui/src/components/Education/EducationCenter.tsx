import type { EducationItem, ClinicalUIState } from '../../types';

interface EducationCenterProps {
  education: EducationItem[];
  uiState?: ClinicalUIState | null;
}

export function EducationCenter({
  education,
  uiState: _uiState,
}: EducationCenterProps) {
  if (education.length === 0) {
    return (
      <section className="card education-center" aria-labelledby="education-heading">
        <header className="card-header">
          <div>
            <h2 id="education-heading">Patient Education</h2>
            <span className="muted small">
              No materials currently recommended
            </span>
          </div>
        </header>

        <div className="empty-state">
          <div className="empty-state-icon" aria-hidden="true">
            📚
          </div>
          <div>
            <strong>No education materials available</strong>
            <p className="muted">
              Education recommendations will appear as the clinical state
              develops.
            </p>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section className="card education-center" aria-labelledby="education-heading">
      <header className="card-header">
        <div>
          <h2 id="education-heading">Patient Education</h2>
          <span className="muted small">
            Materials selected from the current clinical state
          </span>
        </div>

        <span className="status-pill status-active">
          {education.length} {education.length === 1 ? 'item' : 'items'}
        </span>
      </header>

      <div className="edu-list">
        {education.map((item) => (
          <EducationItemCard
            key={item.educationCode}
            item={item}
          />
        ))}
      </div>
    </section>
  );
}

function EducationItemCard({
  item,
}: {
  item: EducationItem;
}) {
  return (
    <article className="edu-card">
      <header className="edu-head">
        <div className="edu-heading">
          <h3 className="edu-title">{item.title}</h3>

          <div className="edu-meta">
            {item.audience && (
              <span className="tag">
                {formatLabel(item.audience)}
              </span>
            )}

            {item.contentType && (
              <span className="tag tag-muted">
                {formatLabel(item.contentType)}
              </span>
            )}
          </div>
        </div>
      </header>

      <div className="edu-body">
        {item.body}
      </div>

      <footer className="edu-footer">
        <span className="muted small">
          Education resource
        </span>

        <span className="mono muted small">
          {item.educationCode}
        </span>
      </footer>
    </article>
  );
}

function formatLabel(value: string): string {
  return value
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());
}