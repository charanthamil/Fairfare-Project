import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 5173,
    /** Listen on all interfaces so phones/tablets on your LAN can open the site */
    host: true,
    open: true,
  },
  /** After `npm run build`, `npm run preview` serves dist/ — also on LAN */
  preview: {
    port: 4173,
    host: true,
    open: true,
  },
});
