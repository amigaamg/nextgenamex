export default function Home() {
  return (
    <main style={{
      minHeight: '100vh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: 'system-ui, sans-serif',
      background: 'linear-gradient(135deg, #1e3a5f 0%, #0f1f3a 100%)',
      color: 'white',
      padding: '2rem'
    }}>
      <h1 style={{
        fontSize: 'clamp(2rem, 5vw, 4rem)',
        fontWeight: 700,
        marginBottom: '1rem',
        background: 'linear-gradient(90deg, #60a5fa, #a78bfa)',
        WebkitBackgroundClip: 'text',
        WebkitTextFillColor: 'transparent'
      }}>
        AMEXAN
      </h1>
      <p style={{
        fontSize: 'clamp(1rem, 2vw, 1.5rem)',
        opacity: 0.8,
        maxWidth: '600px',
        textAlign: 'center',
        marginBottom: '2rem'
      }}>
        Clinical Intelligence Operating System
      </p>
      <div style={{
        display: 'flex',
        gap: '1rem',
        flexWrap: 'wrap',
        justifyContent: 'center'
      }}>
        <a
          href="/api/health"
          style={{
            padding: '0.75rem 1.5rem',
            background: 'rgba(96, 165, 250, 0.2)',
            border: '1px solid #60a5fa',
            borderRadius: '0.5rem',
            color: '#60a5fa',
            textDecoration: 'none',
            fontWeight: 500
          }}
        >
          Health Check
        </a>
        <a
          href="https://github.com/amigaamg/AMEXAN"
          target="_blank"
          rel="noopener noreferrer"
          style={{
            padding: '0.75rem 1.5rem',
            background: 'transparent',
            border: '1px solid rgba(255,255,255,0.3)',
            borderRadius: '0.5rem',
            color: 'white',
            textDecoration: 'none',
            fontWeight: 500
          }}
        >
          GitHub Repository
        </a>
      </div>
    </main>
  )
}