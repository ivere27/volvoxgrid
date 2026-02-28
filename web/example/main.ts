/**
 * VolvoxGrid Web Demo -- Four runtime-switchable scenarios.
 *
 * 1. Stress Test (1M rows)
 * 2. Sales Showcase (~1000 rows, subtotals, merge, combos)
 * 3. Hierarchy Showcase (~200 rows, directory tree with outline)
 * 4. DOOM (optional; local `make doom-deps` assets or remote fallback)
 *
 * Demo data setup is handled by the engine's demo module (via WASM exports),
 * so the host only provides platform glue.
 */

import { VolvoxGrid } from "../js/src/volvoxgrid.js";
import { setupDefaultInput } from "../js/src/default-input.js";
import { createCanvas2DTextRenderer } from "../js/src/canvas2d-text-renderer.js";
import {
  DoomRuntime,
  DOOM_LOCAL_SOURCE,
  DOOM_REMOTE_CONSENT_KEY,
  DOOM_RESOLUTIONS,
  type DoomAssetSource,
} from "./doom.js";

type DemoMode = "stress" | "sales" | "hierarchy" | "doom";
type StandardDemoMode = Exclude<DemoMode, "doom">;

const STRESS_ROWS = 1_000_000;
const STRESS_COLS = 12;
const SALES_COLS = 10;
const HIERARCHY_COLS = 5;
const FONT_FETCH_TIMEOUT_MS = 3000;
type WasmModule = typeof import("./wasm/volvoxgrid_wasm.js");

async function fetchFontWithTimeout(url: string): Promise<Uint8Array | null> {
  const ctrl = new AbortController();
  const timer = window.setTimeout(() => ctrl.abort(), FONT_FETCH_TIMEOUT_MS);
  try {
    const resp = await fetch(url, { signal: ctrl.signal });
    if (!resp.ok) {
      return null;
    }
    return new Uint8Array(await resp.arrayBuffer());
  } catch {
    return null;
  } finally {
    window.clearTimeout(timer);
  }
}

function loadDemoFontsInBackground(
  wasmModule: WasmModule,
  onFontLoaded: () => void,
): void {
  const fontUrl =
    "https://cdn.jsdelivr.net/gh/googlefonts/roboto-2@main/src/hinted/Roboto-Regular.ttf";

  void (async () => {
    const fontData = await fetchFontWithTimeout(fontUrl);
    if (!fontData) {
      console.warn("Could not load demo font - grid text may be missing");
      return;
    }
    wasmModule.load_font(fontData);
    console.info("Loaded demo font");
    onFontLoaded();
  })();
}

/**
 * wasm-bindgen-futures multithread executor calls Atomics.waitAsync even when
 * the thread-pool fails to initialise (memory isn't SharedArrayBuffer).
 * This guard prevents throws on unsupported contexts/non-shared arrays.
 * Must be called BEFORE the WASM module is instantiated.
 */
function installAtomicsWaitAsyncGuard(): void {
  if (typeof Atomics === "undefined") return;
  const atomics = Atomics as typeof Atomics & { __volvoxgridWaitAsyncGuarded?: boolean };
  if (atomics.__volvoxgridWaitAsyncGuarded) return;
  const real = atomics.waitAsync;
  if (typeof real !== "function") return;
  const hasSharedArrayBuffer = typeof SharedArrayBuffer !== "undefined";
  atomics.waitAsync = ((
    ta: Int32Array,
    index: number,
    value: number,
    timeout?: number,
  ) => {
    if (!hasSharedArrayBuffer || !(ta instanceof Int32Array) || !(ta.buffer instanceof SharedArrayBuffer)) {
      return { async: false, value: "not-equal" };
    }
    try {
      if (timeout === undefined) {
        return real(ta, index >>> 0, value);
      }
      return real(ta, index >>> 0, value, timeout);
    } catch {
      return { async: false, value: "not-equal" };
    }
  }) as typeof Atomics.waitAsync;
  atomics.__volvoxgridWaitAsyncGuarded = true;
}

async function main() {
  const status = document.getElementById("status")!;
  const canvas = document.getElementById("grid-canvas") as HTMLCanvasElement;
  const doomRow = document.getElementById("doom-row")!;
  const doomWarning = document.getElementById("doom-warning")!;
  const doomRemoteModal = document.getElementById("doom-remote-modal") as HTMLDivElement;
  const chkDoomRemoteRemember = document.getElementById("chk-doom-remote-remember") as HTMLInputElement;
  const btnDoomRemoteCancel = document.getElementById("btn-doom-remote-cancel") as HTMLButtonElement;
  const btnDoomRemoteContinue = document.getElementById("btn-doom-remote-continue") as HTMLButtonElement;
  const stressConfirmModal = document.getElementById("stress-confirm-modal") as HTMLDivElement;
  const btnStressCancel = document.getElementById("btn-stress-cancel") as HTMLButtonElement;
  const btnStressContinue = document.getElementById("btn-stress-continue") as HTMLButtonElement;
  const selCanvasRes = document.getElementById("sel-canvas-res") as HTMLSelectElement;
  const selTextCache = document.getElementById("sel-text-cache") as HTMLSelectElement;
  const selDoomRes = document.getElementById("sel-doom-res") as HTMLSelectElement;
  const chkDoomBorder = document.getElementById("chk-doom-border") as HTMLInputElement;

  installAtomicsWaitAsyncGuard();

  const wasmModule = await import("./wasm/volvoxgrid_wasm.js");
  await wasmModule.default();
  if (typeof wasmModule.init_v1_plugin === "function") {
    try {
      wasmModule.init_v1_plugin();
    } catch (err) {
      console.warn("WASM v1 plugin init failed (continuing with legacy APIs):", err);
    }
  }

  // Register Canvas2D text renderer only when the built-in engine is absent (Lite mode)
  const hasBuiltinText = typeof (wasmModule as any).has_builtin_text_engine === "function"
    && (wasmModule as any).has_builtin_text_engine();
  let canvas2DRenderer: any = null;
  if (!hasBuiltinText && typeof (wasmModule as any).set_text_renderer === "function") {
    canvas2DRenderer = createCanvas2DTextRenderer(wasmModule);
    canvas2DRenderer.setCacheSize(selectedTextLayoutCacheCap());
    (wasmModule as any).set_text_renderer(canvas2DRenderer.measureText, canvas2DRenderer.renderText);
    console.info("Registered Canvas2D external text renderer (Lite mode)");
  }

  // Enable multithreaded Rayon only when browser/runtime requirements are met.
  const hasThreadPoolInit = typeof wasmModule.init_wasm_thread_pool === "function";
  const sharedArrayBufferCtor =
    (globalThis as { SharedArrayBuffer?: unknown }).SharedArrayBuffer as
      | (new (...args: never[]) => SharedArrayBuffer)
      | undefined;
  const hasSharedArrayBuffer = typeof sharedArrayBufferCtor === "function";
  const wasmMemory = typeof wasmModule.wasm_memory === "function" ? wasmModule.wasm_memory() : null;
  const hasSharedWasmMemory =
    hasSharedArrayBuffer &&
    wasmMemory != null &&
    wasmMemory.buffer instanceof sharedArrayBufferCtor;

  if (hasThreadPoolInit && crossOriginIsolated && hasSharedArrayBuffer && hasSharedWasmMemory) {
    const hw = navigator.hardwareConcurrency || 1;
    const threads = Math.max(1, Math.min(8, hw));
    try {
      await wasmModule.init_wasm_thread_pool(threads);
      console.info(`WASM thread pool initialized (${threads} threads)`);
    } catch (err) {
      console.warn("WASM thread pool init failed; falling back to single-thread mode:", err);
    }
  } else if (hasThreadPoolInit) {
    const reasons: string[] = [];
    if (!crossOriginIsolated) reasons.push("crossOriginIsolated=false");
    if (!hasSharedArrayBuffer) reasons.push("SharedArrayBuffer unavailable");
    if (!hasSharedWasmMemory) reasons.push("WASM memory is not shared");
    console.info(`WASM thread pool disabled (${reasons.join(", ") || "unsupported environment"})`);
  }

  status.textContent = "Starting grid...";
  const rawDeviceScale = window.devicePixelRatio || 1;
  const deviceScale = Number.isFinite(rawDeviceScale) && rawDeviceScale > 0
    ? rawDeviceScale
    : 1;
  const normalizeDpiScale = (raw: number): number => {
    return Number.isFinite(raw) && raw > 0.01 ? raw : 1;
  };
  const getCurrentDeviceScale = (): number => {
    const raw = window.devicePixelRatio || deviceScale;
    return normalizeDpiScale(raw);
  };
  let currentRenderDpiScale = getCurrentDeviceScale();
  const gridDpiScaleById = new Map<number, number>();
  const gridFontReadabilityBoostById = new Map<number, number>();

  const createScaledGrid = (rows: number, cols: number): number => {
    const createGridScaled = (wasmModule as any).create_grid_scaled as
      | ((r: number, c: number, s: number) => number)
      | undefined;
    
    let id: number;
    if (typeof createGridScaled === "function") {
      id = Number(createGridScaled(rows, cols, currentRenderDpiScale));
    } else {
      id = Number((wasmModule as any).create_grid(rows, cols));
    }

    // Also register the external renderer for this specific grid (for measurement/auto-size)
    if (!hasBuiltinText && typeof (wasmModule as any).set_grid_text_renderer === "function") {
      const renderer = canvas2DRenderer ?? createCanvas2DTextRenderer(wasmModule);
      (wasmModule as any).set_grid_text_renderer(id, renderer.measureText, renderer.renderText);
    }

    gridDpiScaleById.set(id, currentRenderDpiScale);
    gridFontReadabilityBoostById.set(id, 1.0);
    return id;
  };

  const applyAndroidLikeDemoStyle = (id: number): void => {
    if (typeof (wasmModule as any).set_font_size === "function") {
      (wasmModule as any).set_font_size(id, 14.0 * currentRenderDpiScale);
    }
  };

  const grid = new VolvoxGrid(canvas, wasmModule, 2, SALES_COLS);
  if (!hasBuiltinText && typeof (wasmModule as any).set_grid_text_renderer === "function") {
    const renderer = canvas2DRenderer ?? createCanvas2DTextRenderer(wasmModule);
    (wasmModule as any).set_grid_text_renderer(grid.id, renderer.measureText, renderer.renderText);
  }
  setupDefaultInput(grid, wasmModule, canvas);
  grid.onZoomChange = () => { updateStatus(); };
  gridDpiScaleById.set(grid.id, currentRenderDpiScale);
  gridFontReadabilityBoostById.set(grid.id, 1.0);
  applyAndroidLikeDemoStyle(grid.id);
  loadDemoFontsInBackground(wasmModule, () => {
    grid.invalidate();
  });

  grid.setRendererMode(2); // AUTO - let tryInitGpu proceed
  const gpuOk = await grid.tryInitGpu();
  grid.setRendererMode(0); // default CPU

  let currentDemo: DemoMode | null = null;
  let dataRows = 0;
  const demoGridIds: Partial<Record<StandardDemoMode, number>> = {
    sales: grid.id,
  };
  const demoInitialized: Partial<Record<StandardDemoMode, boolean>> = {};
  let activeRendererMode = 0;
  let doomGridId: number | null = null;
  const doomRuntime = new DoomRuntime();
  let switchToken = 0;

  function knownGridIds(): number[] {
    const ids = new Set<number>();
    ids.add(grid.id);
    for (const mode of Object.keys(demoGridIds) as StandardDemoMode[]) {
      const id = demoGridIds[mode];
      if (typeof id === "number" && id > 0) {
        ids.add(id);
      }
    }
    if (doomGridId != null && doomGridId > 0) {
      ids.add(doomGridId);
    }
    return Array.from(ids);
  }

  function applyDpiScaleToGrid(id: number, nextScaleRaw: number): void {
    const nextScale = normalizeDpiScale(nextScaleRaw);
    const prevScale = normalizeDpiScale(gridDpiScaleById.get(id) ?? nextScale);
    const relative = nextScale / prevScale;
    const nativeScale = getCurrentDeviceScale();
    const scaleRatio = nextScale / nativeScale;
    const nextFontBoost = scaleRatio >= 1.0
      ? 1.0
      : 1.0 + ((1.0 - scaleRatio) * 0.5);
    const prevFontBoost = Number.isFinite(gridFontReadabilityBoostById.get(id) ?? 1.0)
      ? (gridFontReadabilityBoostById.get(id) ?? 1.0)
      : 1.0;
    const setGridScale = (wasmModule as any).set_grid_scale as
      | ((gridId: number, scale: number) => void)
      | undefined;

    if (!Number.isFinite(relative) || relative <= 0) {
      gridDpiScaleById.set(id, nextScale);
      if (typeof setGridScale === "function") {
        setGridScale(id, nextScale);
      }
      return;
    }

    if (Math.abs(relative - 1.0) > 0.0001) {
      const getFontSize = (wasmModule as any).get_font_size as ((gridId: number) => number) | undefined;
      const setFontSize = (wasmModule as any).set_font_size as
        | ((gridId: number, size: number) => void)
        | undefined;
      if (typeof getFontSize === "function" && typeof setFontSize === "function") {
        const prevFont = Number(getFontSize(id));
        if (Number.isFinite(prevFont) && prevFont > 0) {
          const boostRatio = nextFontBoost / Math.max(0.0001, prevFontBoost);
          const nextFont = Math.max(1, Math.round(prevFont * relative * boostRatio * 10) / 10);
          setFontSize(id, nextFont);
        }
      }

      const getDefaultRowHeight =
        (wasmModule as any).get_default_row_height as ((gridId: number) => number) | undefined;
      const setDefaultRowHeight =
        (wasmModule as any).set_default_row_height as ((gridId: number, h: number) => void) | undefined;
      if (typeof getDefaultRowHeight === "function" && typeof setDefaultRowHeight === "function") {
        const prevRowH = Number(getDefaultRowHeight(id));
        if (Number.isFinite(prevRowH) && prevRowH > 0) {
          setDefaultRowHeight(id, Math.max(1, Math.round(prevRowH * relative)));
        }
      }

      const getDefaultColWidth =
        (wasmModule as any).get_default_col_width as ((gridId: number) => number) | undefined;
      const setDefaultColWidth =
        (wasmModule as any).set_default_col_width as ((gridId: number, w: number) => void) | undefined;
      if (typeof getDefaultColWidth === "function" && typeof setDefaultColWidth === "function") {
        const prevColW = Number(getDefaultColWidth(id));
        if (Number.isFinite(prevColW) && prevColW > 0) {
          setDefaultColWidth(id, Math.max(1, Math.round(prevColW * relative)));
        }
      }

      const scaleRowHeightOverrides =
        (wasmModule as any).scale_row_height_overrides as ((gridId: number, s: number) => void) | undefined;
      if (typeof scaleRowHeightOverrides === "function") {
        scaleRowHeightOverrides(id, relative);
      }

      const scaleColWidthOverrides =
        (wasmModule as any).scale_col_width_overrides as ((gridId: number, s: number) => void) | undefined;
      if (typeof scaleColWidthOverrides === "function") {
        scaleColWidthOverrides(id, relative);
      }
    }

    gridDpiScaleById.set(id, nextScale);
    gridFontReadabilityBoostById.set(id, nextFontBoost);
    if (typeof setGridScale === "function") {
      setGridScale(id, nextScale);
    }
  }

  function applyDpiScaleToKnownGrids(nextScaleRaw: number): void {
    const nextScale = normalizeDpiScale(nextScaleRaw);
    for (const id of knownGridIds()) {
      applyDpiScaleToGrid(id, nextScale);
    }
  }

  const chkDebug = document.getElementById("chk-debug") as HTMLInputElement;
  const chkGpu = document.getElementById("chk-gpu") as HTMLInputElement;
  const chkAnim = document.getElementById("chk-anim") as HTMLInputElement;

  function selectedTextLayoutCacheCap(): number {
    const parsed = Number.parseInt(selTextCache.value, 10);
    if (Number.isFinite(parsed) && parsed >= 0) {
      return parsed;
    }
    return 8192;
  }

  function applyActiveRenderSettings(): void {
    grid.setRendererMode(activeRendererMode);
    grid.setDebugOverlay(chkDebug.checked);
    grid.setAnimationEnabled(chkAnim.checked);
    grid.setTextLayoutCacheCap(selectedTextLayoutCacheCap());
  }

  const fmt = (n: number) => n.toLocaleString("en-US");
  let lastSortInfo = "";

  function colsForCurrentDemo(): number {
    switch (currentDemo) {
      case "stress": return STRESS_COLS;
      case "sales": return SALES_COLS;
      case "hierarchy": return HIERARCHY_COLS;
      default: return 0;
    }
  }

  function updateStatus(extra?: string) {
    if (currentDemo === "doom") return;
    const label = currentDemo
      ? currentDemo.charAt(0).toUpperCase() + currentDemo.slice(1)
      : "Grid";
    const cols = colsForCurrentDemo();
    const zoom = Math.round(grid.zoomScale * 100);
    let text = `${label}: ${fmt(dataRows)} rows x ${cols} cols`;
    if (zoom !== 100) {
      text += ` · Zoom ${zoom}%`;
    }
    if (extra) {
      text += ` · ${extra}`;
    } else if (lastSortInfo) {
      text += ` · ${lastSortInfo}`;
    }
    status.textContent = text;
  }

  const demoBtns: Record<DemoMode, HTMLElement> = {
    stress: document.getElementById("btn-demo-stress")!,
    sales: document.getElementById("btn-demo-sales")!,
    hierarchy: document.getElementById("btn-demo-hierarchy")!,
    doom: document.getElementById("btn-demo-doom")!,
  };

  function setDoomOptionsVisible(visible: boolean) {
    doomRow.classList.toggle("hidden", !visible);
  }

  function setDoomWarning(message: string | null): void {
    if (!message) {
      doomWarning.classList.remove("show");
      doomWarning.textContent = "";
      return;
    }
    doomWarning.textContent = message;
    doomWarning.classList.add("show");
  }

  function hasRemoteDoomConsent(): boolean {
    try {
      return localStorage.getItem(DOOM_REMOTE_CONSENT_KEY) === "allow";
    } catch {
      return false;
    }
  }

  function rememberRemoteDoomConsentIfNeeded(accepted: boolean): void {
    if (!accepted || !chkDoomRemoteRemember.checked) {
      return;
    }
    try {
      localStorage.setItem(DOOM_REMOTE_CONSENT_KEY, "allow");
    } catch {
      // Ignore storage errors (private mode, blocked storage).
    }
  }

  let remoteDoomConsentAcceptedSession = false;
  let remoteConsentPromptInFlight: Promise<boolean> | null = null;
  function requestRemoteDoomConsent(): Promise<boolean> {
    if (remoteDoomConsentAcceptedSession) {
      return Promise.resolve(true);
    }
    if (hasRemoteDoomConsent()) {
      remoteDoomConsentAcceptedSession = true;
      return Promise.resolve(true);
    }
    if (remoteConsentPromptInFlight) {
      return remoteConsentPromptInFlight;
    }

    remoteConsentPromptInFlight = new Promise((resolve) => {
      let finished = false;
      const close = (accepted: boolean) => {
        if (finished) return;
        finished = true;
        if (accepted) {
          remoteDoomConsentAcceptedSession = true;
        }
        rememberRemoteDoomConsentIfNeeded(accepted);
        doomRemoteModal.classList.remove("show");
        doomRemoteModal.setAttribute("aria-hidden", "true");
        btnDoomRemoteCancel.removeEventListener("click", onCancel);
        btnDoomRemoteContinue.removeEventListener("click", onContinue);
        doomRemoteModal.removeEventListener("click", onBackdropClick);
        document.removeEventListener("keydown", onKeyDown, true);
        remoteConsentPromptInFlight = null;
        resolve(accepted);
      };
      const onCancel = () => close(false);
      const onContinue = () => close(true);
      const onBackdropClick = (event: MouseEvent) => {
        if (event.target === doomRemoteModal) {
          close(false);
        }
      };
      const onKeyDown = (event: KeyboardEvent) => {
        if (event.key === "Escape") {
          event.preventDefault();
          close(false);
        }
      };

      chkDoomRemoteRemember.checked = false;
      doomRemoteModal.classList.add("show");
      doomRemoteModal.setAttribute("aria-hidden", "false");
      btnDoomRemoteCancel.addEventListener("click", onCancel);
      btnDoomRemoteContinue.addEventListener("click", onContinue);
      doomRemoteModal.addEventListener("click", onBackdropClick);
      document.addEventListener("keydown", onKeyDown, true);
      btnDoomRemoteContinue.focus();
    });

    return remoteConsentPromptInFlight;
  }

  let stressConsentAccepted = false;
  let stressConsentPromptInFlight: Promise<boolean> | null = null;
  function requestStressModeConsent(): Promise<boolean> {
    if (stressConsentAccepted) {
      return Promise.resolve(true);
    }
    if (stressConsentPromptInFlight) {
      return stressConsentPromptInFlight;
    }

    stressConsentPromptInFlight = new Promise((resolve) => {
      let finished = false;
      const close = (accepted: boolean) => {
        if (finished) return;
        finished = true;
        if (accepted) {
          stressConsentAccepted = true;
        }
        stressConfirmModal.classList.remove("show");
        stressConfirmModal.setAttribute("aria-hidden", "true");
        btnStressCancel.removeEventListener("click", onCancel);
        btnStressContinue.removeEventListener("click", onContinue);
        stressConfirmModal.removeEventListener("click", onBackdropClick);
        document.removeEventListener("keydown", onKeyDown, true);
        stressConsentPromptInFlight = null;
        resolve(accepted);
      };
      const onCancel = () => close(false);
      const onContinue = () => close(true);
      const onBackdropClick = (event: MouseEvent) => {
        if (event.target === stressConfirmModal) {
          close(false);
        }
      };
      const onKeyDown = (event: KeyboardEvent) => {
        if (event.key === "Escape") {
          event.preventDefault();
          close(false);
        }
      };

      stressConfirmModal.classList.add("show");
      stressConfirmModal.setAttribute("aria-hidden", "false");
      btnStressCancel.addEventListener("click", onCancel);
      btnStressContinue.addEventListener("click", onContinue);
      stressConfirmModal.addEventListener("click", onBackdropClick);
      document.addEventListener("keydown", onKeyDown, true);
      btnStressContinue.focus();
    });

    return stressConsentPromptInFlight;
  }

  async function checkDoomDepsReady(): Promise<{
    ok: boolean;
    source?: DoomAssetSource;
    message?: string;
  }> {
    const res = await doomRuntime.resolveAssetSource();
    if (res.ok && res.source?.id === "remote") {
      console.info("DOOM mode: using remote fallback assets through Vite proxy.");
    }
    return res;
  }

  function highlightDemoBtn(mode: DemoMode) {
    for (const key of Object.keys(demoBtns) as DemoMode[]) {
      const btn = demoBtns[key];
      if (key === mode) {
        btn.classList.add("active");
      } else {
        btn.classList.remove("active");
      }
    }
  }

  function colsForDemo(mode: StandardDemoMode): number {
    switch (mode) {
      case "stress":
        return STRESS_COLS;
      case "sales":
        return SALES_COLS;
      case "hierarchy":
        return HIERARCHY_COLS;
    }
  }

  function applyDemoViewDefaults(mode: StandardDemoMode) {
    grid.fixedRows = 1;
    grid.fixedCols = mode === "hierarchy" ? 0 : 1;
    grid.setHighlight(1);
    grid.setFocusRect(2);
    grid.setSelectionMode(0);
    grid.setExplorerBar(3);
    grid.setScrollBars(3);
  }

  function applyDoomGridLayout() {
    const doomCols = doomRuntime.getCols();
    const doomRows = doomRuntime.getRows();
    grid.fixedRows = 0;
    grid.fixedCols = 0;
    grid.setHighlight(0);
    grid.setFocusRect(0);
    grid.setSelectionMode(0);
    grid.setExplorerBar(0);
    grid.setScrollBars(0);
    grid.setGridLines(chkDoomBorder.checked ? 1 : 0);

    // Compute cell sizes to fill the rendered canvas area.
    const scale = getCurrentDeviceScale();
    const cw = canvasRenderOverride
      ? Math.max(1, Math.round(canvasRenderOverride[0]))
      : Math.max(1, Math.round(canvas.clientWidth * scale));
    const ch = canvasRenderOverride
      ? Math.max(1, Math.round(canvasRenderOverride[1]))
      : Math.max(1, Math.round(canvas.clientHeight * scale));
    const baseColW = Math.max(1, Math.floor(cw / doomCols));
    const baseRowH = Math.max(1, Math.floor(ch / doomRows));
    const extraCols = Math.max(0, cw - baseColW * doomCols);
    const extraRows = Math.max(0, ch - baseRowH * doomRows);

    for (let c = 0; c < doomCols; c += 1) {
      grid.setColWidth(c, baseColW + (c < extraCols ? 1 : 0));
    }
    for (let r = 0; r < doomRows; r += 1) {
      grid.setRowHeight(r, baseRowH + (r < extraRows ? 1 : 0));
    }

    grid.invalidate();
  }

  type CanvasResolution = [number, number];
  const CANVAS_RESOLUTION_RATIO_PRESETS: ReadonlyArray<readonly [label: string, scale: number]> = [
    ["2/3", 2 / 3],
    ["3/4", 3 / 4],
    ["4/5", 4 / 5],
    ["3/2", 3 / 2],
    ["2/1", 2],
  ];
  let canvasRenderOverride: CanvasResolution | null = null;

  function currentCanvasCssSize(): [number, number] {
    const rect = canvas.getBoundingClientRect();
    const w = Math.max(1, Math.round(canvas.clientWidth || rect.width || window.innerWidth || 1));
    const h = Math.max(1, Math.round(canvas.clientHeight || rect.height || window.innerHeight || 1));
    return [w, h];
  }

  function currentAutoCanvasResolution(): CanvasResolution {
    const [cssW, cssH] = currentCanvasCssSize();
    const scale = getCurrentDeviceScale();
    const w = Math.max(1, Math.round(cssW * scale));
    const h = Math.max(1, Math.round(cssH * scale));
    return [w, h];
  }

  function parseCanvasResolutionRatio(value: string): number | null {
    if (!value.startsWith("ratio:")) {
      return null;
    }
    const ratioLabel = value.slice("ratio:".length);
    const ratio = CANVAS_RESOLUTION_RATIO_PRESETS.find(([label]) => label === ratioLabel);
    return ratio ? ratio[1] : null;
  }

  function parseCanvasResolutionValue(value: string): CanvasResolution | null {
    if (value === "auto") {
      return null;
    }
    const ratio = parseCanvasResolutionRatio(value);
    if (ratio != null) {
      if (!Number.isFinite(ratio) || ratio <= 0) {
        return null;
      }
      const [baseW, baseH] = currentAutoCanvasResolution();
      return [
        Math.max(1, Math.round(baseW * ratio)),
        Math.max(1, Math.round(baseH * ratio)),
      ];
    }
    const match = /^(\d+)x(\d+)$/.exec(value);
    if (!match) {
      return null;
    }
    const w = Number(match[1]);
    const h = Number(match[2]);
    if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0) {
      return null;
    }
    return [Math.round(w), Math.round(h)];
  }

  function rebuildCanvasResolutionOptions(preserveSelection: boolean): void {
    const prevIndex = selCanvasRes.selectedIndex;
    const prevValue = selCanvasRes.value;
    const [autoW, autoH] = currentAutoCanvasResolution();
    selCanvasRes.innerHTML = "";
    selCanvasRes.add(new Option(`AUTO (${autoW} × ${autoH})`, "auto"));
    for (const [label, scale] of CANVAS_RESOLUTION_RATIO_PRESETS) {
      const width = Math.max(1, Math.round(autoW * scale));
      const height = Math.max(1, Math.round(autoH * scale));
      selCanvasRes.add(new Option(`${label} (${width} × ${height})`, `ratio:${label}`));
    }

    if (!preserveSelection) {
      selCanvasRes.value = "auto";
      return;
    }

    if (prevValue === "auto") {
      selCanvasRes.value = "auto";
      return;
    }

    let selected = false;
    const hasPrevValue = Array.from(selCanvasRes.options).some((opt) => opt.value === prevValue);
    if (hasPrevValue) {
      selCanvasRes.value = prevValue;
      selected = true;
    }

    if (!selected && prevIndex >= 0 && prevIndex < selCanvasRes.options.length) {
      selCanvasRes.selectedIndex = prevIndex;
      selected = true;
    }

    if (!selected) {
      selCanvasRes.value = "auto";
    }
  }

  function canvasResolutionDpiScale(value: string, preset: CanvasResolution | null): number {
    if (value === "auto") {
      return getCurrentDeviceScale();
    }

    const ratio = parseCanvasResolutionRatio(value);
    if (ratio != null) {
      return normalizeDpiScale(getCurrentDeviceScale() * ratio);
    }

    if (!preset) {
      return getCurrentDeviceScale();
    }

    const [cssW, cssH] = currentCanvasCssSize();
    const scaleX = preset[0] / cssW;
    const scaleY = preset[1] / cssH;
    return normalizeDpiScale((scaleX + scaleY) * 0.5);
  }

  function applyCanvasResolutionPreset(value: string): void {
    const preset = parseCanvasResolutionValue(value);
    canvas.style.width = "100%";
    canvas.style.height = "100%";
    if (!preset) {
      canvasRenderOverride = null;
      grid.setRenderResolution(null, null);
    } else {
      canvasRenderOverride = [preset[0], preset[1]];
      grid.setRenderResolution(preset[0], preset[1]);
    }
    const nextDpiScale = canvasResolutionDpiScale(value, preset);
    currentRenderDpiScale = nextDpiScale;
    applyDpiScaleToKnownGrids(nextDpiScale);

    requestAnimationFrame(() => {
      if (currentDemo === "doom") {
        applyDoomGridLayout();
      } else {
        grid.invalidate();
      }
    });
  }

  function ensureDemoGrid(mode: StandardDemoMode): number {
    let id = demoGridIds[mode];
    if (id == null) {
      id = createScaledGrid(2, colsForDemo(mode));
      applyAndroidLikeDemoStyle(id);
      demoGridIds[mode] = id;
    }
    if (demoInitialized[mode]) {
      return id;
    }

    const prevId = grid.id;
    if (id !== prevId) {
      grid.useGrid(id);
    }

    switch (mode) {
      case "stress":
        wasmModule.demo_setup_stress_grid(id);
        break;
      case "sales":
        wasmModule.demo_setup_sales_demo(id);
        break;
      case "hierarchy":
        wasmModule.demo_setup_hierarchy_demo(id);
        break;
    }

    wasmModule.set_fast_scroll_enabled(id, true);
    applyDemoViewDefaults(mode);
    grid.invalidate();
    demoInitialized[mode] = true;

    if (id !== prevId) {
      grid.useGrid(prevId);
    }
    return id;
  }

  function ensureDoomGridId(): number {
    if (doomGridId == null) {
      doomGridId = createScaledGrid(doomRuntime.getRows(), doomRuntime.getCols());
    }
    return doomGridId;
  }

  async function activateDoomDemo(token: number): Promise<boolean> {
    let source = doomRuntime.getSourceInUse();
    if (!doomRuntime.hasSession() || !source) {
      const deps = await checkDoomDepsReady();
      if (!deps.ok) {
        setDoomWarning(deps.message ?? "DOOM mode is not ready.");
        status.textContent = deps.message ?? "DOOM mode is not ready.";
        return false;
      }
      source = deps.source ?? DOOM_LOCAL_SOURCE;

      if (source.id === "remote") {
        const accepted = await requestRemoteDoomConsent();
        if (!accepted) {
          const msg = "Remote DOOM asset download was canceled.";
          setDoomWarning(msg);
          status.textContent = msg;
          return false;
        }
        if (token !== switchToken) {
          return false;
        }
      }

      setDoomWarning(null);
      status.textContent = source.id === "remote"
        ? "Starting DOOM emulator (remote fallback assets)..."
        : "Starting DOOM emulator...";
      try {
        await doomRuntime.ensureEmulator(source);
      } catch (err) {
        const raw = String(err);
        const hint = source.id === "remote"
          ? "Check network/proxy access, or run 'make doom-deps' and reload."
          : "Run 'make doom-deps' and reload the page.";
        const msg = raw.includes(source.emulatorsScriptPath) || raw.includes(source.bundlePath)
          ? `DOOM assets are missing or invalid. ${hint}`
          : `DOOM failed to start: ${raw}`;
        console.error(msg, err);
        setDoomWarning(msg);
        status.textContent = msg;
        return false;
      }
    } else {
      setDoomWarning(null);
    }

    if (token !== switchToken) {
      return false;
    }

    const doomId = ensureDoomGridId();
    grid.useGrid(doomId);
    applyActiveRenderSettings();
    applyDoomGridLayout();
    doomRuntime.startRenderLoop(grid, status);

    return true;
  }

  async function switchDemo(mode: DemoMode) {
    if (mode === currentDemo) return;

    if (mode === "stress" && !stressConsentAccepted) {
      const accepted = await requestStressModeConsent();
      if (!accepted) {
        status.textContent = "Stress mode startup was canceled.";
        return;
      }
    }

    const token = ++switchToken;

    if (currentDemo === "doom" && mode !== "doom") {
      doomRuntime.stopRenderLoop();
      doomRuntime.releaseAllDosKeys();
    }

    if (mode === "doom") {
      const ok = await activateDoomDemo(token);
      if (!ok || token !== switchToken) {
        return;
      }
      currentDemo = "doom";
      setDoomOptionsVisible(true);
      highlightDemoBtn("doom");
      return;
    }

    setDoomOptionsVisible(false);

    const demoId = ensureDemoGrid(mode);
    if (token !== switchToken) {
      return;
    }

    grid.useGrid(demoId);
    applyActiveRenderSettings();

    currentDemo = mode;
    highlightDemoBtn(mode);
    dataRows = Math.max(0, grid.rows - 1);

    switch (mode) {
      case "stress": {
        status.textContent = "Initialising 1,000,000-row grid...";
        applyDemoViewDefaults(mode);
        break;
      }
      case "sales": {
        status.textContent = "Loading Sales demo...";
        applyDemoViewDefaults(mode);
        break;
      }
      case "hierarchy": {
        status.textContent = "Loading Hierarchy demo...";
        applyDemoViewDefaults(mode);
        break;
      }
    }
    lastSortInfo = "";
    updateStatus();

    grid.invalidate();
  }

  setDoomOptionsVisible(false);

  rebuildCanvasResolutionOptions(false);
  selCanvasRes.addEventListener("change", () => {
    applyCanvasResolutionPreset(selCanvasRes.value);
  });
  applyCanvasResolutionPreset(selCanvasRes.value);

  // Initial demo.
  await switchDemo("sales");

  // Demo switch buttons.
  demoBtns.stress.addEventListener("click", () => {
    void switchDemo("stress");
  });
  demoBtns.sales.addEventListener("click", () => {
    void switchDemo("sales");
  });
  demoBtns.hierarchy.addEventListener("click", () => {
    void switchDemo("hierarchy");
  });
  demoBtns.doom.addEventListener("click", () => {
    void switchDemo("doom");
  });

  // Resolution selector.
  selDoomRes.addEventListener("change", () => {
    const preset = DOOM_RESOLUTIONS[selDoomRes.value];
    if (!preset) return;
    doomRuntime.setResolution(preset[0], preset[1]);
    doomGridId = null;

    if (currentDemo === "doom") {
      doomRuntime.releaseAllDosKeys();
      const token = ++switchToken;
      void activateDoomDemo(token).then((ok) => {
        if (!ok || token !== switchToken) {
          return;
        }
        currentDemo = "doom";
        setDoomOptionsVisible(true);
        highlightDemoBtn("doom");
      });
    }
  });

  chkDoomBorder.addEventListener("change", () => {
    if (currentDemo !== "doom") return;
    applyDoomGridLayout();
  });

  // Keyboard forwarding for DOOM only.
  document.addEventListener("keydown", (e) => {
    if (currentDemo !== "doom") return;
    const handled = doomRuntime.handleKeyDown(e.code, e.repeat);
    if (handled) {
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);

  document.addEventListener("keyup", (e) => {
    if (currentDemo !== "doom") return;
    const handled = doomRuntime.handleKeyUp(e.code);
    if (handled) {
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);

  window.addEventListener("blur", () => {
    if (currentDemo === "doom") {
      doomRuntime.releaseAllDosKeys();
    }
  });

  // Resize handler for DOOM layout.
  let resizeTimer = 0;
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(() => {
      rebuildCanvasResolutionOptions(true);
      applyCanvasResolutionPreset(selCanvasRes.value);
      if (currentDemo === "doom") {
        applyDoomGridLayout();
      }
    }, 100);
  });

  // Toolbar handlers.
  document.getElementById("btn-sort-asc")!.addEventListener("click", () => {
    const col = grid.selectionCol >= 0 ? grid.selectionCol : 0;
    const t0 = performance.now();
    grid.sort(1, col);
    const ms = (performance.now() - t0).toFixed(1);
    lastSortInfo = `Sort: col ${col} ASC (${ms}ms)`;
    updateStatus();
  });

  document.getElementById("btn-sort-desc")!.addEventListener("click", () => {
    const col = grid.selectionCol >= 0 ? grid.selectionCol : 0;
    const t0 = performance.now();
    grid.sort(2, col);
    const ms = (performance.now() - t0).toFixed(1);
    lastSortInfo = `Sort: col ${col} DESC (${ms}ms)`;
    updateStatus();
  });

  document.getElementById("btn-sort-none")!.addEventListener("click", () => {
    const col = grid.selectionCol >= 0 ? grid.selectionCol : 0;
    grid.sort(0, col);
    grid.invalidate();
    lastSortInfo = "";
    updateStatus();
  });

  document.getElementById("btn-add-rows")!.addEventListener("click", () => {
    if (currentDemo !== "stress") return;
    dataRows += 100_000;
    grid.rows = dataRows + 1;
    wasmModule.demo_materialize_visible_rows(grid.id, 48);
    grid.invalidate();
    updateStatus();
  });

  // AddItem: insert 5 rows at current selection.
  document.getElementById("btn-add-item")!.addEventListener("click", () => {
    if (currentDemo === "doom") return;
    const row = grid.selectionRow;
    const insertAt = row >= 1 ? row + 1 : 1;
    for (let i = 0; i < 5; i += 1) {
      const r = insertAt + i;
      const text = `${r}\tNew-${r}\tAdded\t${r * 50}\tQ1\tNorth\tActive\t50%\tnew note\tRed`;
      grid.addItem(text, insertAt + i);
    }
    dataRows += 5;
    grid.invalidate();
    status.textContent = `Added 5 rows at ${insertAt} (${fmt(dataRows)} rows)`;
  });

  // RemoveItem: delete current row.
  document.getElementById("btn-del-item")!.addEventListener("click", () => {
    if (currentDemo === "doom") return;
    const row = grid.selectionRow;
    if (row >= grid.fixedRows && dataRows > 1) {
      grid.removeItem(row);
      dataRows -= 1;
      grid.invalidate();
      status.textContent = `Deleted row ${row} (${fmt(dataRows)} rows)`;
    } else {
      status.textContent = "Cannot delete: select a data row";
    }
  });

  // ColFormat toggle.
  let colFmtOn = true;
  document.getElementById("btn-col-fmt")!.addEventListener("click", () => {
    if (currentDemo === "doom") return;
    const btn = document.getElementById("btn-col-fmt")!;
    if (colFmtOn) {
      grid.setColFormat(3, "");
      btn.textContent = "ColFmt";
      colFmtOn = false;
    } else {
      grid.setColFormat(3, "$#,##0.00");
      btn.textContent = "ColFmt:$";
      colFmtOn = true;
    }
    grid.invalidate();
  });

  // ExplorerBar mode cycle.
  let explorerBar = 3;
  document.getElementById("btn-expl-bar")!.addEventListener("click", () => {
    if (currentDemo === "doom") return;
    explorerBar = (explorerBar + 1) % 4;
    grid.setExplorerBar(explorerBar);
    const labels = ["ExplBar:Off", "ExplBar:Sort", "ExplBar:Move", "ExplBar:3"];
    document.getElementById("btn-expl-bar")!.textContent = labels[explorerBar];
    grid.invalidate();
  });

  // AutoSize all columns.
  document.getElementById("btn-autosize")!.addEventListener("click", () => {
    if (currentDemo === "doom") return;
    const cols = grid.cols;
    for (let c = 0; c < cols; c += 1) {
      grid.autoResizeCol(c);
    }
    grid.invalidate();
    status.textContent = `Auto-sized ${cols} columns`;
  });

  // GPU/CPU toggle.
  chkGpu.disabled = !gpuOk;
  chkGpu.checked = false;
  chkGpu.addEventListener("change", () => {
    activeRendererMode = chkGpu.checked ? 1 : 0;
    applyActiveRenderSettings();
    grid.invalidate();
  });

  // Animation toggle.
  chkAnim.addEventListener("change", () => {
    applyActiveRenderSettings();
    grid.invalidate();
  });

  // Debug overlay toggle.
  chkDebug.addEventListener("change", () => {
    applyActiveRenderSettings();
    grid.invalidate();
  });

  // Text layout cache cap.
  selTextCache.addEventListener("change", () => {
    const cap = selectedTextLayoutCacheCap();
    grid.setTextLayoutCacheCap(cap);
    if (canvas2DRenderer) {
      canvas2DRenderer.setCacheSize(cap);
    }
    grid.invalidate();
  });

  // Initial scale can be configured from `make web WEB_SCALE=<value>`.
  const env = (import.meta as any).env as Record<string, string | undefined>;
  const envZoom = Number(env?.VITE_VG_INITIAL_SCALE ?? "");
  const ZOOM_MIN = 0.3;
  const ZOOM_MAX = 3.0;
  let zoomLevel = Number.isFinite(envZoom) && envZoom > 0 ? envZoom : 1.0;
  zoomLevel = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, zoomLevel));
  const rawBaseFont = typeof (wasmModule as any).get_font_size === "function"
    ? Number((wasmModule as any).get_font_size(grid.id))
    : 14.0 * deviceScale;
  const baseFontSize = Number.isFinite(rawBaseFont) && rawBaseFont > 0
    ? rawBaseFont
    : 14.0 * deviceScale;
  const baseRowHeight = Number(wasmModule.get_default_row_height(grid.id));
  const baseColWidth = Number(wasmModule.get_default_col_width(grid.id));

  function applyZoom() {
    grid.setFontSize(Math.round(baseFontSize * zoomLevel * 10) / 10);
    wasmModule.set_default_row_height(grid.id, Math.round(baseRowHeight * zoomLevel));
    wasmModule.set_default_col_width(grid.id, Math.round(baseColWidth * zoomLevel));
    grid.invalidate();
  }

  applyZoom();
}

main().catch((err) => {
  console.error("VolvoxGrid demo failed:", err);
  const status = document.getElementById("status");
  if (status) {
    status.textContent = "Error: " + String(err);
  }
});
