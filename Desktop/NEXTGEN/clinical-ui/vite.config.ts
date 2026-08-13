import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The UI is not the intelligence. It talks only to the Clinical Runtime API
// (4.37); vite proxies those calls to the API server during development.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8787',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
      '/events': {
        target: 'http://localhost:8787',
        changeOrigin: true,
      },
    },
  },
});
