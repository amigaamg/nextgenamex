import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// The UI is not the intelligence. It talks only to the Clinical Runtime API
// (4.37); vite proxies those calls to the API server during development.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    proxy: {
      // Control Plane API: /api/control-plane/admin/* → /admin/* (the
      // read-only operational surface), /api/control-plane/events/* →
      // /admin/events/*, /api/control-plane/observatory → /observatory.
      '/api/control-plane': {
        target: 'http://localhost:8787',
        changeOrigin: true,
        rewrite: (path) => {
          const rest = path
            .replace(/^\/api\/control-plane/, '')
            .replace(/^\/+/, '');
          return rest.startsWith('events/')
            ? `/admin/${rest}`
            : `/${rest}`;
        },
      },
      '/api': {
        target: 'http://localhost:8787',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
      '/clinical': {
        target: 'http://localhost:8787',
        changeOrigin: true,
      },
      '/events': {
        target: 'http://localhost:8787',
        changeOrigin: true,
      },
    },
  },
});
