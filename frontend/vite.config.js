/// <reference types="vitest" />
import { defineConfig, transformWithOxc } from 'vite';
import react from '@vitejs/plugin-react';

const transformJsxInJs = () => ({
  name: 'transform-jsx-in-js',
  enforce: 'pre',
  async transform(code, id) {
    if (!id.includes('src/')) return null;
    if (!id.endsWith('.js')) return null;
    return await transformWithOxc(code, id, { lang: 'jsx' });
  },
});

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), transformJsxInJs()],
  optimizeDeps: {
    rolldownOptions: {
      moduleTypes: {
        '.js': 'jsx',
      },
    },
  },
  server: {
    port: 3000,
  },
  preview: {
    port: 3000,
  },
  build: {
    outDir: 'dist',
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/setupTests.js'],
    include: ['src/**/*.{test,spec}.{js,jsx,ts,tsx}'],
  },
});
