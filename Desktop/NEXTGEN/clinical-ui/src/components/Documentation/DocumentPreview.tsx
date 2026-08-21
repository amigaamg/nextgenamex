import { useEffect, useState } from 'react';
import { exportDocumentation } from '../../api';
import { CrossIcon, DownloadIcon } from '../Icons';

interface DocumentPreviewProps {
  patientId: string;
  encounterId: string;
  onClose: () => void;
}

type PreviewStatus = 'loading' | 'ready' | 'error';

export function DocumentPreview({
  patientId,
  encounterId,
  onClose,
}: DocumentPreviewProps) {
  const [objectUrl, setObjectUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<PreviewStatus>('loading');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let disposed = false;
    let createdUrl: string | null = null;

    setStatus('loading');
    setErrorMessage(null);

    exportDocumentation(patientId, encounterId)
      .then((blob) => {
        if (disposed) return;
        createdUrl = URL.createObjectURL(blob);
        setObjectUrl(createdUrl);
        setStatus('ready');
      })
      .catch((cause) => {
        if (disposed) return;
        setErrorMessage(
          cause instanceof Error
            ? cause.message
            : 'Failed to generate the clinical record.',
        );
        setStatus('error');
      });

    return () => {
      disposed = true;
      if (createdUrl) URL.revokeObjectURL(createdUrl);
    };
  }, [patientId, encounterId]);

  useEffect(() => {
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [onClose]);

  const handleDownload = () => {
    if (!objectUrl) return;
    const anchor = document.createElement('a');
    anchor.href = objectUrl;
    anchor.download = `amexan-encounter-${encounterId}.pdf`;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  };

  return (
    <div
      className="document-preview-backdrop"
      onClick={onClose}
      role="presentation"
    >
      <section
        className="document-preview"
        role="dialog"
        aria-modal="true"
        aria-label="Clinical record preview"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="document-preview-header">
          <div className="document-preview-title">
            <span className="document-preview-kicker">AMEXAN</span>
            <h2>Clinical Record</h2>
          </div>

          <div className="document-preview-actions">
            {status === 'ready' && (
              <button
                type="button"
                className="btn btn-primary btn-small"
                onClick={handleDownload}
              >
                <span aria-hidden="true">
                  <DownloadIcon size={15} />
                </span>
                Download PDF
              </button>
            )}
            <button
              type="button"
              className="btn btn-tertiary btn-small"
              onClick={onClose}
            >
              <span aria-hidden="true">
                <CrossIcon size={15} />
              </span>
              Close
            </button>
          </div>
        </header>

        <div className="document-preview-body">
          {status === 'loading' && (
            <div className="document-preview-status">
              Generating the clinical record…
            </div>
          )}
          {status === 'error' && (
            <div className="document-preview-status document-preview-error">
              Could not generate the record — {errorMessage}
            </div>
          )}
          {status === 'ready' && objectUrl && (
            <embed
              key={objectUrl}
              className="document-preview-embed"
              src={objectUrl}
              type="application/pdf"
              title="Clinical record PDF"
            />
          )}
        </div>
      </section>
    </div>
  );
}
