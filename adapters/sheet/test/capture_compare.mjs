/**
 * capture_compare.mjs — Puppeteer-based capture of VolvoxSheet test cases.
 *
 * Each test case is a .txt script in test/cases/. Each line is an API call.
 * Uses Vite dev server to serve the capture HTML (handles TS transpilation).
 *
 * Usage:
 *   node test/capture_compare.mjs [--out DIR] [--test N] [--tests LIST]
 *     [--settle-ms N] [--grid-width N] [--grid-height N]
 *     [--font PATH] [--font-family NAME] [--debug-page]
 */

import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import { resolve, extname } from "node:path";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createServer as createHttpServer } from "node:http";
import puppeteer from "puppeteer";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ADAPTER_DIR = resolve(__dirname, "..");
const ROOT_DIR = resolve(ADAPTER_DIR, "../..");
const CASES_DIR = resolve(__dirname, "cases");

// ── CLI args ──

let outDir = resolve(ROOT_DIR, "target/sheet/compare");
let testFilter = null;
let captureFontPath = null;
let captureFontFamily = "";
let debugPage = false;
let settleMs = 500;
let gridWidth = 820;
let gridHeight = 560;
let viewportWidth = 0;
let viewportHeight = 0;
let viewportWidthExplicit = false;
let viewportHeightExplicit = false;

const cliArgs = process.argv.slice(2);
for (let i = 0; i < cliArgs.length; i++) {
  const arg = cliArgs[i];
  if (arg === "--out" && cliArgs[i + 1]) {
    outDir = resolve(cliArgs[++i]);
  } else if (arg.startsWith("--out=")) {
    outDir = resolve(arg.slice(6));
  } else if (arg === "--test" && cliArgs[i + 1]) {
    testFilter = parseFilter(cliArgs[++i]);
  } else if (arg.startsWith("--test=")) {
    testFilter = parseFilter(arg.slice(7));
  } else if (arg === "--tests" && cliArgs[i + 1]) {
    testFilter = parseFilter(cliArgs[++i]);
  } else if (arg.startsWith("--tests=")) {
    testFilter = parseFilter(arg.slice(8));
  } else if (arg === "--font" && cliArgs[i + 1]) {
    captureFontPath = resolve(cliArgs[++i]);
  } else if (arg.startsWith("--font=")) {
    captureFontPath = resolve(arg.slice(7));
  } else if (arg === "--font-family" && cliArgs[i + 1]) {
    captureFontFamily = cliArgs[++i].trim();
  } else if (arg.startsWith("--font-family=")) {
    captureFontFamily = arg.slice(14).trim();
  } else if (arg === "--debug-page") {
    debugPage = true;
  } else if (arg === "--settle-ms" && cliArgs[i + 1]) {
    settleMs = parseSettleMs(cliArgs[++i]);
  } else if (arg.startsWith("--settle-ms=")) {
    settleMs = parseSettleMs(arg.slice(12));
  } else if (arg === "--grid-width" && cliArgs[i + 1]) {
    gridWidth = parseDimension(cliArgs[++i], gridWidth);
  } else if (arg.startsWith("--grid-width=")) {
    gridWidth = parseDimension(arg.slice(13), gridWidth);
  } else if (arg === "--grid-height" && cliArgs[i + 1]) {
    gridHeight = parseDimension(cliArgs[++i], gridHeight);
  } else if (arg.startsWith("--grid-height=")) {
    gridHeight = parseDimension(arg.slice(14), gridHeight);
  } else if (arg === "--viewport-width" && cliArgs[i + 1]) {
    viewportWidth = parseDimension(cliArgs[++i], 1200);
    viewportWidthExplicit = true;
  } else if (arg.startsWith("--viewport-width=")) {
    viewportWidth = parseDimension(arg.slice(17), 1200);
    viewportWidthExplicit = true;
  } else if (arg === "--viewport-height" && cliArgs[i + 1]) {
    viewportHeight = parseDimension(cliArgs[++i], 700);
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
  return Number.isFinite(parsed) ? Math.max(0, parsed) : 500;
}

function parseDimension(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? Math.max(320, parsed) : fallback;
}

if (!viewportWidthExplicit) {
  viewportWidth = Math.max(1200, gridWidth + 200);
}
if (!viewportHeightExplicit) {
  viewportHeight = Math.max(700, gridHeight + 200);
}

// ── Discover test case scripts ──

async function discoverCases() {
  const files = await readdir(CASES_DIR);
  const sorted = files
    .filter((f) => f.endsWith(".txt"))
    .sort((a, b) => {
      const ma = a.match(/^(\d+)_/);
      const mb = b.match(/^(\d+)_/);
      const ia = ma ? Number(ma[1]) : Number.POSITIVE_INFINITY;
      const ib = mb ? Number(mb[1]) : Number.POSITIVE_INFINITY;
      if (ia !== ib) return ia - ib;
      return a.localeCompare(b);
    });
  const cases = [];
  for (const f of sorted) {
    const match = f.match(/^(\d+)_(.+)\.txt$/);
    if (!match) continue;
    const id = Number(match[1]);
    const name = match[2];
    const scriptPath = resolve(CASES_DIR, f);
    const script = await readFile(scriptPath, "utf8");
    cases.push({ id, name, scriptFile: f, script });
  }
  return cases;
}

// ── Font server (supplements Vite) ──

function createFontServer(fontPath) {
  return createHttpServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname === "/__volvox_font__.ttf") {
      if (!fontPath || !existsSync(fontPath)) {
        res.writeHead(404);
        res.end("Font not configured");
        return;
      }
      try {
        const data = await readFile(fontPath);
        res.writeHead(200, {
          "Content-Type": "font/ttf",
          "Cache-Control": "no-store",
          "Access-Control-Allow-Origin": "*",
        });
        res.end(data);
      } catch (err) {
        res.writeHead(500);
        res.end(String(err));
      }
      return;
    }
    res.writeHead(404);
    res.end("Not found");
  });
}

// ── Main ──

async function main() {
  await mkdir(outDir, { recursive: true });

  if (captureFontPath && !existsSync(captureFontPath)) {
    console.warn(`WARNING: capture font not found: ${captureFontPath}`);
    captureFontPath = null;
  }

  // Discover test cases
  const allCases = await discoverCases();
  const cases = testFilter
    ? allCases.filter((c) => testFilter.has(c.id))
    : allCases;

  if (cases.length === 0) {
    console.error("No test cases found!");
    process.exit(1);
  }

  console.log(`Found ${allCases.length} test cases, running ${cases.length}.`);

  // Start font server if needed
  let fontServerUrl = "";
  let fontServer = null;
  if (captureFontPath) {
    fontServer = createFontServer(captureFontPath);
    await new Promise((r) => fontServer.listen(0, "127.0.0.1", r));
    const fontPort = fontServer.address().port;
    fontServerUrl = `http://127.0.0.1:${fontPort}`;
    console.log(`Font server on ${fontServerUrl}`);
  }

  // Start Vite dev server
  console.log("Starting Vite dev server...");
  const { createServer: createViteServer } = await import("vite");
  const viteServer = await createViteServer({
    root: ADAPTER_DIR,
    server: {
      port: 0,
      strictPort: false,
      fs: {
        allow: [ADAPTER_DIR, ROOT_DIR],
      },
    },
    configFile: resolve(ADAPTER_DIR, "vite.config.ts"),
    logLevel: debugPage ? "info" : "silent",
  });
  await viteServer.listen();
  const viteAddress = viteServer.httpServer.address();
  const viteUrl = `http://127.0.0.1:${viteAddress.port}`;
  console.log(`Vite server on ${viteUrl}`);

  // Build capture page URL
  const query = new URLSearchParams();
  if (captureFontFamily) query.set("vv-font-family", captureFontFamily);
  query.set("settle-ms", String(settleMs));
  query.set("grid-width", String(gridWidth));
  query.set("grid-height", String(gridHeight));
  const captureUrl = `${viteUrl}/test/capture_compare.html?${query.toString()}`;

  if (captureFontPath) {
    console.log(`Capture font: ${captureFontFamily || captureFontPath}`);
  }
  console.log(`Grid: ${gridWidth}x${gridHeight}, viewport: ${viewportWidth}x${viewportHeight}`);

  // Launch Puppeteer
  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-gpu"],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: viewportWidth, height: viewportHeight });

  if (debugPage) {
    page.on("console", (msg) => console.log(`[page:${msg.type()}] ${msg.text()}`));
    page.on("pageerror", (err) => console.log(`[page:error] ${err?.stack ?? String(err)}`));
    page.on("requestfailed", (req) => console.log(`[page:fail] ${req.url()} ${req.failure()?.errorText ?? ""}`));
  }

  // Intercept font requests from the page and redirect to font server
  if (captureFontPath && fontServerUrl) {
    await page.setRequestInterception(true);
    page.on("request", (request) => {
      if (request.url().includes("__volvox_font__")) {
        request.continue({ url: `${fontServerUrl}/__volvox_font__.ttf` });
      } else {
        request.continue();
      }
    });
  }

  console.log(`Loading: ${captureUrl}`);
  await page.goto(captureUrl, { waitUntil: "networkidle0", timeout: 30000 });

  // Wait for page ready
  await page.waitForFunction(() => window.__pageReady === true, { timeout: 15000 });
  console.log("Page ready. Running test cases...\n");

  // Run each case
  for (const tc of cases) {
    const numStr = String(tc.id).padStart(2, "0");
    const baseName = `test_${numStr}_${tc.name}`;
    const label = `[${numStr}] ${tc.name}`;

    // Execute script
    await page.evaluate(
      (script, lbl) => window.__runScript(script, { label: lbl }),
      tc.script,
      label,
    );

    // Wait for capture ready
    await page.waitForFunction(() => window.__captureReady === true, { timeout: 15000 });

    const error = await page.evaluate(() => window.__error);
    if (error) {
      console.error(`  ERROR [${numStr}] ${tc.name}: ${error}`);
      continue;
    }

    // Capture screenshot
    const vxEl = await page.$("#vx-grid");
    if (vxEl) {
      const imgPath = resolve(outDir, `${baseName}_vv.png`);
      await vxEl.screenshot({ path: imgPath });
    }

    console.log(`  ${label}`);
  }

  // Cleanup
  await page.close();
  await browser.close();
  await viteServer.close();
  if (fontServer) fontServer.close();

  // Write scripts.json
  const scriptsMap = {};
  for (const tc of allCases) {
    scriptsMap[String(tc.id).padStart(2, "0")] = tc.script;
  }
  await writeFile(resolve(outDir, "scripts.json"), JSON.stringify(scriptsMap, null, 2));

  console.log(`\nCapture complete: ${outDir}/`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
