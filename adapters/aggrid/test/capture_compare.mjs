/**
 * capture_compare.mjs — Puppeteer-based capture of AG Grid vs VolvoxGrid.
 *
 * Serves a static HTML page, initialises each test case in headless Chromium,
 * and captures screenshots of the reference and VolvoxGrid containers.
 *
 * Usage:
 *   node test/capture_compare.mjs [--out DIR] [--test N] [--tests LIST] [--only-vv]
 */

import { createServer } from "node:http";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { resolve, join, extname } from "node:path";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";
import { compareCases } from "./compare_cases.mjs";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ADAPTER_DIR = resolve(__dirname, "..");
const ROOT_DIR = resolve(ADAPTER_DIR, "../..");

// ── CLI args ──

let outDir = resolve(ROOT_DIR, "target/aggrid/compare");
let testFilter = null;  // null = all
let onlyVv = false;
let captureFontPath = null;
let captureFontFamily = "";
let fallbackFontPath = null;
let debugPage = false;
let settleMs = 500;
let gridWidth = 960;
let gridHeight = 720;
let viewportWidth = 0;
let viewportHeight = 0;
let viewportWidthExplicit = false;
let viewportHeightExplicit = false;

const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === "--out" && args[i + 1]) {
    outDir = resolve(args[++i]);
  } else if (arg.startsWith("--out=")) {
    outDir = resolve(arg.slice(6));
  } else if (arg === "--test" && args[i + 1]) {
    testFilter = parseFilter(args[++i]);
  } else if (arg.startsWith("--test=")) {
    testFilter = parseFilter(arg.slice(7));
  } else if (arg === "--tests" && args[i + 1]) {
    testFilter = parseFilter(args[++i]);
  } else if (arg.startsWith("--tests=")) {
    testFilter = parseFilter(arg.slice(8));
  } else if (arg === "--only-vv") {
    onlyVv = true;
  } else if (arg === "--font" && args[i + 1]) {
    captureFontPath = resolve(args[++i]);
  } else if (arg.startsWith("--font=")) {
    captureFontPath = resolve(arg.slice(7));
  } else if (arg === "--font-family" && args[i + 1]) {
    captureFontFamily = args[++i].trim();
  } else if (arg.startsWith("--font-family=")) {
    captureFontFamily = arg.slice(14).trim();
  } else if (arg === "--fallback-font" && args[i + 1]) {
    fallbackFontPath = resolve(args[++i]);
  } else if (arg.startsWith("--fallback-font=")) {
    fallbackFontPath = resolve(arg.slice(16));
  } else if (arg === "--debug-page") {
    debugPage = true;
  } else if (arg === "--settle-ms" && args[i + 1]) {
    settleMs = parseSettleMs(args[++i]);
  } else if (arg.startsWith("--settle-ms=")) {
    settleMs = parseSettleMs(arg.slice(12));
  } else if (arg === "--grid-width" && args[i + 1]) {
    gridWidth = parseDimension(args[++i], gridWidth);
  } else if (arg.startsWith("--grid-width=")) {
    gridWidth = parseDimension(arg.slice(13), gridWidth);
  } else if (arg === "--grid-height" && args[i + 1]) {
    gridHeight = parseDimension(args[++i], gridHeight);
  } else if (arg.startsWith("--grid-height=")) {
    gridHeight = parseDimension(arg.slice(14), gridHeight);
  } else if (arg === "--viewport-width" && args[i + 1]) {
    viewportWidth = parseDimension(args[++i], 1800);
    viewportWidthExplicit = true;
  } else if (arg.startsWith("--viewport-width=")) {
    viewportWidth = parseDimension(arg.slice(17), 1800);
    viewportWidthExplicit = true;
  } else if (arg === "--viewport-height" && args[i + 1]) {
    viewportHeight = parseDimension(args[++i], 700);
    viewportHeightExplicit = true;
  } else if (arg.startsWith("--viewport-height=")) {
    viewportHeight = parseDimension(arg.slice(18), 700);
    viewportHeightExplicit = true;
  }
}

function parseFilter(s) {
  const ids = new Set();
  for (const part of s.split(",")) {
    if (part.includes("-")) {
      const [lo, hi] = part.split("-").map(Number);
      for (let n = lo; n <= hi; n++) ids.add(n);
    } else {
      ids.add(Number(part));
    }
  }
  return ids;
}

function parseSettleMs(value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return 500;
  }
  return Math.max(0, parsed);
}

function parseDimension(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.max(320, parsed);
}

if (!viewportWidthExplicit) {
  viewportWidth = Math.max(1800, (gridWidth * 2) + 260);
}
if (!viewportHeightExplicit) {
  viewportHeight = Math.max(700, gridHeight + 260);
}

// ── MIME types ──

const MIME = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".mjs": "application/javascript",
  ".css": "text/css",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".map": "application/json",
};

// ── Static file server ──

function createStaticServer(fontPath, fallbackPath) {
  const routes = [
    { prefix: "/adapter/", root: ADAPTER_DIR },
    { prefix: "/wasm/", root: resolve(ROOT_DIR, "dist/wasm") },
    { prefix: "/volvoxgrid_js/", root: resolve(ROOT_DIR, "web/js") },
    { prefix: "/node_modules/", root: resolve(ADAPTER_DIR, "node_modules") },
  ];

  return createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    let filePath = null;

    if (url.pathname === "/__volvox_font__.ttf" || url.pathname === "/__volvox_fallback_font__.ttf") {
      const servePath = url.pathname === "/__volvox_fallback_font__.ttf" ? fallbackPath : fontPath;
      if (!servePath || !existsSync(servePath)) {
        res.writeHead(404);
        res.end("Font not configured");
        return;
      }
      try {
        const data = await readFile(servePath);
        res.writeHead(200, {
          "Content-Type": "font/ttf",
          "Cache-Control": "no-store",
        });
        res.end(data);
      } catch (err) {
        res.writeHead(500);
        res.end(String(err));
      }
      return;
    }

    for (const route of routes) {
      if (url.pathname.startsWith(route.prefix)) {
        const relPath = url.pathname.slice(route.prefix.length);
        filePath = resolve(route.root, relPath);
        break;
      }
    }

    // Serve the capture page at root
    if (url.pathname === "/" || url.pathname === "/index.html") {
      filePath = resolve(__dirname, "capture_compare.html");
    }

    if (!filePath || !existsSync(filePath)) {
      res.writeHead(404);
      res.end(`Not found: ${url.pathname}`);
      return;
    }

    try {
      const data = await readFile(filePath);
      const ext = extname(filePath);
      res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream" });
      res.end(data);
    } catch (err) {
      res.writeHead(500);
      res.end(String(err));
    }
  });
}

// ── Main ──

async function main() {
  await mkdir(outDir, { recursive: true });

  if (captureFontPath && !existsSync(captureFontPath)) {
    console.warn(`WARNING: capture font file not found: ${captureFontPath}`);
    captureFontPath = null;
  }
  if (fallbackFontPath && !existsSync(fallbackFontPath)) {
    console.warn(`WARNING: fallback font file not found: ${fallbackFontPath}`);
    fallbackFontPath = null;
  }

  const server = createStaticServer(captureFontPath, fallbackFontPath);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;
  const query = new URLSearchParams();
  if (captureFontFamily) {
    query.set("vv-font-family", captureFontFamily);
  }
  query.set("settle-ms", String(settleMs));
  query.set("grid-width", String(gridWidth));
  query.set("grid-height", String(gridHeight));
  const captureUrl = `${baseUrl}/?${query.toString()}`;

  console.log(`Static server on ${baseUrl}`);
  if (captureFontPath) {
    if (captureFontFamily) {
      console.log(`Capture font: ${captureFontFamily} (${captureFontPath})`);
    } else {
      console.log(`Capture font: ${captureFontPath}`);
    }
  } else {
    console.log("Capture font: none (VolvoxGrid text may be blank)");
  }
  console.log(`Capture geometry: viewport ${viewportWidth}x${viewportHeight}, grid ${gridWidth}x${gridHeight}`);

  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-gpu"],
  });

  const cases = testFilter
    ? compareCases.filter((c) => testFilter.has(c.id))
    : compareCases;

  const page = await browser.newPage();
  await page.setViewport({ width: viewportWidth, height: viewportHeight });
  if (debugPage) {
    page.on("console", (msg) => {
      const text = msg.text();
      console.log(`[page:${msg.type()}] ${text}`);
    });
    page.on("pageerror", (err) => {
      const message = err?.stack ?? String(err);
      console.log(`[page:pageerror] ${message}`);
    });
    page.on("requestfailed", (req) => {
      console.log(`[page:requestfailed] ${req.url()} ${req.failure()?.errorText ?? ""}`);
    });
  }
  await page.goto(captureUrl, { waitUntil: "networkidle0" });

  for (const tc of cases) {
    // Initialise test case
    await page.evaluate((id) => window.__initCase(id), tc.id);

    // Wait for capture ready
    await page.waitForFunction(() => window.__captureReady === true, {
      timeout: 15000,
    });

    if (captureFontFamily) {
      await page.evaluate(() => window.__forceCaptureFont?.());
      await new Promise((resolve) => setTimeout(resolve, 120));
    }

    const error = await page.evaluate(() => window.__error);
    if (error) {
      console.error(`  ERROR on case ${tc.id}: ${error}`);
      continue;
    }

    const numStr = String(tc.id).padStart(2, "0");
    const baseName = `test_${numStr}_${tc.name}`;

    // Capture reference grid
    if (!onlyVv) {
      const refEl = await page.$("#ref-grid");
      if (refEl) {
        await refEl.screenshot({ path: join(outDir, `${baseName}_ref.png`) });
      }
    }

    // Capture VolvoxGrid
    const vvEl = await page.$("#vv-grid");
    if (vvEl) {
      await vvEl.screenshot({ path: join(outDir, `${baseName}_vv.png`) });
    }

    console.log(`[${numStr}] ${tc.name}`);
  }

  await page.close();
  await browser.close();
  server.close();

  // Write scripts.json for HTML report generation
  const scriptsMap = {};
  for (const tc of compareCases) {
    const scriptKey = String(tc.id).padStart(2, "0");
    let scriptContent = "";

    if (typeof tc.scriptFile === "string" && tc.scriptFile.length > 0) {
      const scriptPath = resolve(__dirname, tc.scriptFile);
      if (existsSync(scriptPath)) {
        scriptContent = await readFile(scriptPath, "utf8");
      }
    }

    if (!scriptContent && typeof tc.script === "string") {
      scriptContent = tc.script;
    }

    scriptsMap[scriptKey] = scriptContent;
  }
  await writeFile(join(outDir, "scripts.json"), JSON.stringify(scriptsMap, null, 2));

  console.log(`\nCapture complete: ${outDir}/`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
