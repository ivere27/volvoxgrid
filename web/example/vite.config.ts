import { defineConfig } from "vite";

const crossOriginIsolationHeaders = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
};

const doomBundleProxyPath = "/doom/remote/vendor/doom.jsdos";
const doomBundleRemotePath = "/custom/dos/doom.jsdos?anonymous=1";
const doomEmulatorsProxyPrefix = "/doom/remote/emulators";
const doomEmulatorsCdnPrefix = "/npm/emulators@8.3.9/dist";

export default defineConfig({
  worker: {
    format: "es",
  },
  server: {
    headers: crossOriginIsolationHeaders,
    proxy: {
      [doomBundleProxyPath]: {
        target: "https://cdn.dos.zone",
        changeOrigin: true,
        rewrite: () => doomBundleRemotePath,
      },
      [doomEmulatorsProxyPrefix]: {
        target: "https://cdn.jsdelivr.net",
        changeOrigin: true,
        rewrite: (path) => path.replace(doomEmulatorsProxyPrefix, doomEmulatorsCdnPrefix),
      },
    },
  },
  preview: {
    headers: crossOriginIsolationHeaders,
  },
});
