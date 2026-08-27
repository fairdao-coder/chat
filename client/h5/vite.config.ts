import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
  },
  build: {
    // output to a fresh dir to avoid the sandbox "safe-delete" lock on dist/
    outDir: 'dist-build3',
    emptyOutDir: true,
  },
});
