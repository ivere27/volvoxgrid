import { defineConfig, type Plugin } from "vite";

declare const process: {
  env: Record<string, string | undefined>;
};

const crossOriginIsolationHeaders = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
};

const doomBundleProxyPath = "/doom/remote/vendor/doom.jsdos";
const doomBundleRemotePath = "/bundles/doom.jsdos";
const doomEmulatorsProxyPrefix = "/doom/remote/emulators";
const doomEmulatorsCdnPrefix = "/npm/emulators@8.3.9/dist";

const VG_EXTERNAL = process.env.VITE_VG_EXTERNAL === "1";
const VG_VERSION = process.env.VITE_VG_VERSION ?? "latest";
const CDN_BASE = "https://cdn.jsdelivr.net/npm";

// Maps relative source-tree imports in the demo to package specifiers,
// so the build can externalize `volvoxgrid` and load it from a CDN.
const externalAliasMap: Record<string, string> = {
  "../js/src/index.js": "volvoxgrid",
  "../js/src/volvoxgrid.js": "volvoxgrid",
  "../js/src/default-input.js": "volvoxgrid",
  "../js/src/canvas2d-text-renderer.js": "volvoxgrid",
  "../js/src/generated/volvoxgrid_ffi.js": "volvoxgrid/generated/volvoxgrid_ffi.js",
  "../js/src/generated/volvoxgrid_lite.js": "volvoxgrid/generated/volvoxgrid_lite.js",
};

function rewriteVolvoxgridImports(): Plugin {
  return {
    name: "volvoxgrid-rewrite-imports",
    enforce: "pre",
    resolveId(source) {
      const replacement = externalAliasMap[source];
      if (replacement) {
        return { id: replacement, external: true };
      }
      return null;
    },
  };
}

function injectVolvoxgridImportmap(version: string): Plugin {
  const imports = {
    volvoxgrid: `${CDN_BASE}/volvoxgrid@${version}/dist/volvoxgrid.min.js`,
    "volvoxgrid/generated/volvoxgrid_ffi.js": `${CDN_BASE}/volvoxgrid@${version}/dist/generated/volvoxgrid_ffi.js`,
    "volvoxgrid/generated/volvoxgrid_lite.js": `${CDN_BASE}/volvoxgrid@${version}/dist/generated/volvoxgrid_lite.js`,
  };
  const tag = `<script type="importmap">${JSON.stringify({ imports })}</script>`;
  return {
    name: "volvoxgrid-inject-importmap",
    transformIndexHtml: {
      order: "pre",
      handler(html) {
        return html.replace(/<head([^>]*)>/i, (m) => `${m}\n  ${tag}`);
      },
    },
  };
}

export default defineConfig({
  plugins: VG_EXTERNAL
    ? [rewriteVolvoxgridImports(), injectVolvoxgridImportmap(VG_VERSION)]
    : [],
  worker: {
    format: "es",
  },
  server: {
    headers: crossOriginIsolationHeaders,
    proxy: {
      [doomBundleProxyPath]: {
        target: "https://v8.js-dos.com",
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
