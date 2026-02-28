import { defineConfig } from "vite";
import { resolve } from "path";

export default defineConfig({
  server: {
    fs: {
      allow: [
        resolve(__dirname),           // adapters/excel/
        resolve(__dirname, "../.."),   // repo root (for symlinked wasm/)
      ],
    },
  },
  build: {
    lib: {
      entry: resolve(__dirname, "src/index.ts"),
      name: "VolvoxExcel",
      formats: ["es", "umd"],
      fileName: (format) =>
        format === "es" ? "volvox-excel.js" : "volvox-excel.umd.js",
    },
    rollupOptions: {
      external: ["volvoxgrid"],
      output: {
        globals: {
          volvoxgrid: "VolvoxGrid",
        },
        assetFileNames: "assets/[name][extname]",
      },
    },
    sourcemap: true,
    assetsInlineLimit: 0, // Never inline assets (prevents 3.8MB font in CSS)
  },
});
