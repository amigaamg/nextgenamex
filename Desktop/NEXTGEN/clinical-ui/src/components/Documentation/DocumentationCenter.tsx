import { useMemo, useState } from 'react';

import type { DocumentationSection } from '../../types';
import {
  type ShorthandSection as ShorthandSectionShape,
  toShorthand,
} from '../../clinical/documentation';
import { NoteIcon } from '../Icons';

interface DocumentationCenterProps {
  sections: DocumentationSection[];
  documentation?: unknown;
  projection?: unknown;
}

type NoteSectionKind = 'list' | 'numbered' | 'prose';

type NoteMode = 'note' | 'shorthand';

function sectionKind(section: string): NoteSectionKind {
  switch (section) {
    case 'biodata':
      return 'list';
    case 'chief_complaint':
      return 'numbered';
    case 'hpi':
      return 'prose';
    default:
      return 'list';
  }
}

const SECTION_TITLES: Record<string, string> = {
  biodata: 'Biodata',
  chief_complaint: 'Chief Complaint',
  hpi: 'History of Presenting Illness',
};

function formatSectionTitle(section: string): string {
  return section
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export function DocumentationCenter({
  sections,
}: DocumentationCenterProps) {
  const [mode, setMode] = useState<NoteMode>('note');

  const shorthandSections = useMemo(
    () => toShorthand(sections),
    [sections],
  );

  const visibleSections =
    mode === 'shorthand' ? shorthandSections : sections;

  if (sections.length === 0) {
    return (
      <section className="card documentation-center">
        <header className="documentation-head">
          <h2>
            <span className="section-icon" aria-hidden="true">
              <NoteIcon size={16} />
            </span>
            Live Documentation
          </h2>

          <span className="muted small">
            The clinical note, written as the history is captured.
          </span>
        </header>

        <div className="documentation-empty">
          <span
            className="documentation-empty-mark"
            aria-hidden="true"
          >
            ✎
          </span>

          <div>
            <strong>Nothing written yet</strong>
            <p className="muted">
              As history taking is saved, the note will be written here —
              the biodata, the numbered chief complaint, and the history of
              presenting illness.
            </p>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section className="card documentation-center documentation-note">
      <header className="documentation-head">
        <h2>
          <span className="section-icon" aria-hidden="true">
            <NoteIcon size={16} />
          </span>
          Live Documentation
        </h2>

        <span className="muted small">
          Written as the history is captured
        </span>

        <div className="doc-mode-switch" role="group" aria-label="Note view">
          <button
            type="button"
            className={mode === 'note' ? 'active' : ''}
            onClick={() => setMode('note')}
          >
            Note
          </button>
          <button
            type="button"
            className={mode === 'shorthand' ? 'active' : ''}
            onClick={() => setMode('shorthand')}
          >
            Shorthand
          </button>
        </div>
      </header>

      <div className="documentation-body">
        {visibleSections.map((section) =>
          mode === 'shorthand' ? (
            <ShorthandSection
              key={section.section}
              section={section as ShorthandSectionShape}
            />
          ) : (
            <NoteSection
              key={section.section}
              section={section}
            />
          ),
        )}
      </div>
    </section>
  );
}

function NoteSection({
  section,
}: {
  section: DocumentationSection;
}) {
  const sentences = section.sentences.filter(
    (item) => item.text.trim().length > 0,
  );

  if (sentences.length === 0) {
    return null;
  }

  const kind = sectionKind(section.section);

  return (
    <article className="doc-note-section">
      <h3>
        {SECTION_TITLES[section.section] ??
          formatSectionTitle(section.section)}
      </h3>

      {kind === 'numbered' ? (
        <ol className="doc-note-numbered">
          {sentences.map((item, index) => (
            <li key={index}>{item.text}</li>
          ))}
        </ol>
      ) : kind === 'prose' ? (
        <p className="doc-note-prose">
          {sentences.map((item) => item.text).join(' ')}
        </p>
      ) : section.section === 'biodata' ? (
        <div className="doc-note-lines">
          {sentences.map((item, index) => (
            <span key={index} className="doc-note-line">
              {item.text}
            </span>
          ))}
        </div>
      ) : (
        <ul className="doc-note-list">
          {sentences.map((item, index) => (
            <li key={index}>{item.text}</li>
          ))}
        </ul>
      )}
    </article>
  );
}

function ShorthandSection({
  section,
}: {
  section: ShorthandSectionShape;
}) {
  const lines = section.sentences.filter(
    (item) => item.text.trim().length > 0,
  );

  if (lines.length === 0) {
    return null;
  }

  return (
    <article className="doc-note-section doc-shorthand-section">
      <h3>{section.title}</h3>

      <div className="doc-shorthand-lines">
        {lines.map((item, index) => (
          <span key={index} className="doc-shorthand-line">
            {item.text}
          </span>
        ))}
      </div>
    </article>
  );
}