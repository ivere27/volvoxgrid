import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 3000,
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
    fs: {
      allow: [
        path.resolve(__dirname),           // adapters/report/
        path.resolve(__dirname, "../.."),   // repo root (for symlinked wasm/)
      ],
    },
  },
  build: {
    target: 'esnext',
  },
  optimizeDeps: {
    exclude: ['volvoxgrid'],
  },
});
