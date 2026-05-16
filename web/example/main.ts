/**
 * VolvoxGrid Web Demo -- Five runtime-switchable scenarios.
 *
 * 1. Stress Test (1M rows)
 * 2. Sales Showcase (~1000 rows, subtotals, merge, combos)
 * 3. Hierarchy Showcase (~200 rows, directory tree with outline)
 * 4. Barcode Showcase (QR and common 1D symbologies)
 * 5. DOOM (optional; local `make doom-deps` assets or remote fallback)
 *
 * Demo data setup is handled by the engine's demo module (via WASM exports),
 * so the host only provides platform glue.
 */

import {
  EditTrigger,
  EditorUpdateReason,
  FocusBorderStyle,
  GridLineStyle,
  PresentMode,
  RenderLayerBit,
  RendererMode,
  ScrollBarsMode,
  SelectionMode,
  SelectionVisibility,
  VolvoxGrid,
  createCanvas2DRasterizer,
  createCanvas2DTextRenderer,
  setupDefaultInput,
  type VolvoxGridContextMenuRequest,
  type VolvoxGridValidationError,
} from "../js/src/index.js";
import {
  GridEvent as GridEventMessage,
  GridEventEventOneofCase,
} from "../js/src/generated/volvoxgrid_lite.js";
import {
  DoomRuntime,
  DOOM_LOCAL_SOURCE,
  DOOM_REMOTE_CONSENT_KEY,
  DOOM_RESOLUTIONS,
  type DoomAssetSource,
} from "./doom.js";
import { BARCODE_COLS, setupBarcodesJsonDemo } from "./barcodes.js";
import {
  CELL_HIT_AREA_TEXT,
  CELL_INTERACTION_TEXT_LINK,
  HIERARCHY_ACTION_COL,
  HIERARCHY_COLS,
  autoSizeHierarchyColumns,
  setupHierarchyJsonDemo,
} from "./hierarchy.js";
import { SALES_COLS, setupSalesJsonDemo } from "./sales.js";
import { STRESS_COLS, setupStressDemo } from "./stress.js";
import {
  type WasmModule,
} from "./shared.js";

const HOVER_NONE = 0;
const HOVER_ROW = 1;
const HOVER_COLUMN = 2;
const HOVER_CELL = 4;

type DemoMode = "stress" | "sales" | "hierarchy" | "barcodes" | "doom";
type StandardDemoMode = Exclude<DemoMode, "doom">;
type DoomDirectionCode = "ArrowUp" | "ArrowDown" | "ArrowLeft" | "ArrowRight";
type DoomTouchActionCode = "ControlLeft" | "Space" | "Enter";

const FONT_FETCH_TIMEOUT_MS = 5000;
const DEMO_DEFAULT_FONT_FAMILY = "Roboto";
const MATERIAL_ICONS_FONT_URL =
  "https://cdn.jsdelivr.net/npm/material-design-icons@3.0.1/iconfont/MaterialIcons-Regular.ttf";
const RENDER_LAYER_PREFIX = "RENDER_LAYER_";
type RenderLayerOption = { bit: number; label: string };
const LAYER_OPTIONS: RenderLayerOption[] = Object.entries(RenderLayerBit)
  .filter((entry): entry is [string, number] =>
    entry[0].startsWith(RENDER_LAYER_PREFIX) && typeof entry[1] === "number")
  .map(([name, bit]) => ({ bit, label: name.slice(RENDER_LAYER_PREFIX.length) }))
  .sort((a, b) => a.bit - b.bit);
const LAYER_MASK_ALL = LAYER_OPTIONS.reduce((mask, layer) => mask + 2 ** layer.bit, 0);
const DEMO_DEFAULT_HOVER_MODE: Record<StandardDemoMode, number> = {
  stress: HOVER_ROW,
  sales: HOVER_ROW | HOVER_COLUMN | HOVER_CELL,
  hierarchy: HOVER_CELL,
  barcodes: HOVER_ROW | HOVER_COLUMN | HOVER_CELL,
};

function gridEventDebugObject(event: GridEventMessage): Record<string, unknown> {
  const eventName = GridEventEventOneofCase[event.eventCase] ?? "None";
  return {
    event: eventName,
    eventId: event.eventId.toString(),
    ...event.toJson(),
  };
}

type DemoFontAsset = {
  label: string;
  url: string;
  family?: string;
  aliases?: string[];
  weight?: string;
  style?: string;
};
type DemoFontLoadResult = {
  font: DemoFontAsset;
  loaded: boolean;
};
type DemoFontLoadSummary = {
  anyLoaded: boolean;
  missingFonts: string[];
  missingTextFonts: string[];
};

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

function browserLocaleHints(): string[] {
  if (typeof navigator === "undefined") {
    return [];
  }
  const locales = Array.isArray(navigator.languages) && navigator.languages.length > 0
    ? navigator.languages
    : [navigator.language];
  return locales
    .map((value) => value?.trim())
    .filter((value): value is string => typeof value === "string" && value.length > 0);
}

function appendDemoFontIfMissing(
  fonts: DemoFontAsset[],
  seenUrls: Set<string>,
  label: string,
  url: string,
  family?: string,
  aliases?: string[],
): void {
  if (seenUrls.has(url)) {
    return;
  }
  seenUrls.add(url);
  fonts.push({ label, url, family, aliases });
}

function appendDemoFontsForLocale(
  locale: string,
  fonts: DemoFontAsset[],
  seenUrls: Set<string>,
): void {
  const normalized = locale.trim().toLowerCase();
  if (normalized === "") {
    return;
  }

  if (/^ko(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans KR (ko)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/KR/NotoSansKR-Regular.otf",
    );
    return;
  }
  if (/^ja(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans JP (ja)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/JP/NotoSansJP-Regular.otf",
    );
    return;
  }
  if (/^zh(?:-|$)/i.test(normalized)) {
    const traditional = /(?:^|[-_])(hant|tw|hk|mo)(?:[-_]|$)/i.test(normalized);
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      traditional ? "Noto Sans TC (zh-Hant)" : "Noto Sans SC (zh-Hans)",
      traditional
        ? "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/TC/NotoSansTC-Regular.otf"
        : "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf",
    );
    return;
  }
  if (/^th(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Thai (th)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansThai/NotoSansThai-Regular.ttf",
    );
    return;
  }
  if (/^ar(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Arabic (ar)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf",
    );
    return;
  }
  if (/^(?:he|iw)(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Hebrew (he)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansHebrew/NotoSansHebrew-Regular.ttf",
    );
    return;
  }
  if (/^(?:hi|mr|ne)(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Devanagari",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansDevanagari/NotoSansDevanagari-Regular.ttf",
    );
    return;
  }
  if (/^bn(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Bengali (bn)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansBengali/NotoSansBengali-Regular.ttf",
    );
    return;
  }
  if (/^ta(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Tamil (ta)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansTamil/NotoSansTamil-Regular.ttf",
    );
    return;
  }
  if (/^te(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Telugu (te)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansTelugu/NotoSansTelugu-Regular.ttf",
    );
    return;
  }
  if (/^ml(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Malayalam (ml)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansMalayalam/NotoSansMalayalam-Regular.ttf",
    );
    return;
  }
  if (/^kn(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Kannada (kn)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansKannada/NotoSansKannada-Regular.ttf",
    );
    return;
  }
  if (/^gu(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Gujarati (gu)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansGujarati/NotoSansGujarati-Regular.ttf",
    );
    return;
  }
  if (/^pa(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Gurmukhi (pa)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansGurmukhi/NotoSansGurmukhi-Regular.ttf",
    );
    return;
  }
  if (/^or(?:-|$)/i.test(normalized)) {
    appendDemoFontIfMissing(
      fonts,
      seenUrls,
      "Noto Sans Oriya (or)",
      "https://cdn.jsdelivr.net/gh/notofonts/noto-fonts@main/hinted/ttf/NotoSansOriya/NotoSansOriya-Regular.ttf",
    );
  }
}

function demoFontAssetsForLocales(locales: readonly string[]): DemoFontAsset[] {
  const fonts: DemoFontAsset[] = [
    {
      label: "Material Icons",
      url: MATERIAL_ICONS_FONT_URL,
      family: "Material Icons",
      aliases: ["MaterialIcons"],
      weight: "400",
    },
    {
      label: "Roboto (Latin)",
      url: "https://cdn.jsdelivr.net/gh/googlefonts/roboto-2@main/src/hinted/Roboto-Regular.ttf",
      family: DEMO_DEFAULT_FONT_FAMILY,
      weight: "400",
    },
    {
      label: "Roboto Bold (Latin)",
      url: "https://cdn.jsdelivr.net/gh/googlefonts/roboto-2@main/src/hinted/Roboto-Bold.ttf",
      family: DEMO_DEFAULT_FONT_FAMILY,
      weight: "700",
    },
  ];
  const seenUrls = new Set<string>(fonts.map((font) => font.url));
  for (const locale of locales) {
    appendDemoFontsForLocale(locale, fonts, seenUrls);
  }
  return fonts;
}

function browserFontFamilies(font: DemoFontAsset): string[] {
  const primary = font.family ?? font.label.replace(/\s*\([^)]*\)\s*$/, "").trim();
  return [primary, ...(font.aliases ?? [])]
    .map((value) => value.trim())
    .filter((value, index, values) => value !== "" && values.indexOf(value) === index);
}

async function loadBrowserFontFaces(font: DemoFontAsset, fontData: Uint8Array): Promise<boolean> {
  if (typeof FontFace === "undefined" || document.fonts == null) {
    return false;
  }

  const families = browserFontFamilies(font);
  if (families.length === 0) {
    return false;
  }

  const source: BufferSource = fontData.buffer instanceof ArrayBuffer
    ? fontData.buffer.slice(fontData.byteOffset, fontData.byteOffset + fontData.byteLength)
    : new Uint8Array(fontData).buffer;
  const loaded = await Promise.all(
    families.map(async (family) => {
      try {
        const face = new FontFace(family, source, {
          weight: font.weight ?? "400",
          style: font.style ?? "normal",
        });
        await face.load();
        document.fonts.add(face);
        return true;
      } catch (err) {
        console.warn(`Could not register browser font ${family}:`, err);
        return false;
      }
    }),
  );
  return loaded.some(Boolean);
}

function isIconFontAsset(font: DemoFontAsset): boolean {
  return font.family === "Material Icons" || (font.aliases ?? []).includes("MaterialIcons");
}

function loadDemoFontsInBackground(
  wasmModule: WasmModule,
): Promise<DemoFontLoadSummary> {
  const fonts = demoFontAssetsForLocales(browserLocaleHints());

  return Promise.all(
    fonts.map(async (font): Promise<DemoFontLoadResult> => {
      const fontData = await fetchFontWithTimeout(font.url);
      if (fontData) {
        try {
          wasmModule.load_font(fontData);
          await loadBrowserFontFaces(font, fontData);
          console.info(`Loaded demo font: ${font.label}`);
          return { font, loaded: true };
        } catch (err) {
          console.warn(`Could not register ${font.label}:`, err);
        }
      } else {
        console.warn(`Could not load ${font.label} - some glyphs may be missing`);
      }
      return { font, loaded: false };
    }),
  )
    .then((results) => ({
      anyLoaded: results.some((result) => result.loaded),
      missingFonts: results
        .filter((result) => !result.loaded)
        .map((result) => result.font.label),
      missingTextFonts: results
        .filter((result) => !result.loaded && !isIconFontAsset(result.font))
        .map((result) => result.font.label),
    }));
}

/**
 * wasm-bindgen-futures multithread executor calls Atomics.waitAsync even when
 * the thread-pool fails to initialise (memory isn't SharedArrayBuffer).
 * This guard prevents throws on unsupported contexts/non-shared arrays.
 * Must be called BEFORE the WASM module is instantiated.
 */
function installAtomicsWaitAsyncGuard(): void {
  if (typeof Atomics === "undefined") return;
  type AtomicsWaitAsync = (
    ta: Int32Array,
    index: number,
    value: number,
    timeout?: number,
  ) => unknown;
  const atomics = Atomics as typeof Atomics & {
    waitAsync?: AtomicsWaitAsync;
    __volvoxgridWaitAsyncGuarded?: boolean;
  };
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
  }) as AtomicsWaitAsync;
  atomics.__volvoxgridWaitAsyncGuarded = true;
}

function parseEnvBool(value: string | undefined, fallback = false): boolean {
  if (value == null) {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === "") {
    return fallback;
  }
  if (normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on") {
    return true;
  }
  if (normalized === "0" || normalized === "false" || normalized === "no" || normalized === "off") {
    return false;
  }
  return fallback;
}

function normalizeBaseUrl(baseUrl: string | undefined): string {
  const raw = (baseUrl ?? "/").trim();
  if (raw === "" || raw === "/") {
    return "/";
  }
  const withLeading = raw.startsWith("/") ? raw : `/${raw}`;
  return withLeading.endsWith("/") ? withLeading : `${withLeading}/`;
}

async function ensureDoomRemoteProxyWorker(baseUrl: string, isDev: boolean): Promise<void> {
  if (isDev) {
    return;
  }
  if (!("serviceWorker" in navigator)) {
    return;
  }
  if (!window.isSecureContext) {
    return;
  }

  try {
    await navigator.serviceWorker.register(`${baseUrl}doom-remote-proxy-sw.js`, {
      scope: baseUrl,
    });
    await Promise.race([
      navigator.serviceWorker.ready,
      new Promise<void>((resolve) => {
        window.setTimeout(resolve, 2000);
      }),
    ]);

    if (!navigator.serviceWorker.controller) {
      await new Promise<void>((resolve) => {
        const onChange = () => {
          navigator.serviceWorker.removeEventListener("controllerchange", onChange);
          resolve();
        };
        navigator.serviceWorker.addEventListener("controllerchange", onChange, { once: true });
        window.setTimeout(() => {
          navigator.serviceWorker.removeEventListener("controllerchange", onChange);
          resolve();
        }, 2000);
      });
    }
  } catch (err) {
    console.warn("DOOM remote proxy worker registration failed:", err);
  }
}

async function main() {
  const status = document.getElementById("status")!;
  const canvas = document.getElementById("grid-canvas") as HTMLCanvasElement;
  const doomRow = document.getElementById("doom-row")!;
  const doomWarning = document.getElementById("doom-warning")!;
  const doomTouchControls = document.getElementById("doom-touch-controls") as HTMLDivElement;
  const doomJoystick = document.getElementById("doom-joystick") as HTMLDivElement;
  const doomJoystickThumb = document.getElementById("doom-joystick-thumb") as HTMLDivElement;
  const btnDoomSelect = document.getElementById("btn-doom-select") as HTMLButtonElement;
  const btnDoomFire = document.getElementById("btn-doom-fire") as HTMLButtonElement;
  const btnDoomUse = document.getElementById("btn-doom-use") as HTMLButtonElement;
  const btnSortAsc = document.getElementById("btn-sort-asc") as HTMLButtonElement;
  const btnSortDesc = document.getElementById("btn-sort-desc") as HTMLButtonElement;
  const btnSortAscMobile = document.getElementById("btn-sort-asc-mobile") as HTMLButtonElement;
  const btnSortDescMobile = document.getElementById("btn-sort-desc-mobile") as HTMLButtonElement;
  const doomRemoteModal = document.getElementById("doom-remote-modal") as HTMLDivElement;
  const chkDoomRemoteRemember = document.getElementById("chk-doom-remote-remember") as HTMLInputElement;
  const btnDoomRemoteCancel = document.getElementById("btn-doom-remote-cancel") as HTMLButtonElement;
  const btnDoomRemoteContinue = document.getElementById("btn-doom-remote-continue") as HTMLButtonElement;
  const stressConfirmModal = document.getElementById("stress-confirm-modal") as HTMLDivElement;
  const btnStressCancel = document.getElementById("btn-stress-cancel") as HTMLButtonElement;
  const btnStressContinue = document.getElementById("btn-stress-continue") as HTMLButtonElement;
  const selTextCache = document.getElementById("sel-text-cache") as HTMLSelectElement;
  const selTextCacheMobile = document.getElementById("sel-text-cache-mobile") as HTMLSelectElement;
  const textCacheSelects = [selTextCache, selTextCacheMobile];
  const selDoomRes = document.getElementById("sel-doom-res") as HTMLSelectElement;
  const chkDoomBorder = document.getElementById("chk-doom-border") as HTMLInputElement;
  const layerDropdown = document.getElementById("layer-dropdown") as HTMLDivElement;
  const mobileMenuDropdown = document.getElementById("mobile-menu-dropdown") as HTMLDivElement;
  const btnLayers = document.getElementById("btn-layers") as HTMLButtonElement;
  const btnMobileMenu = document.getElementById("btn-mobile-menu") as HTMLButtonElement;
  const layerPanel = document.getElementById("layer-panel") as HTMLDivElement;
  const layerPanelOptions = document.getElementById("layer-panel-options") as HTMLDivElement;
  const btnLayersAll = document.getElementById("btn-layers-all") as HTMLButtonElement;
  const btnLayersNone = document.getElementById("btn-layers-none") as HTMLButtonElement;
  const env = (import.meta as any).env as Record<string, string | undefined>;
  const isDev = Boolean((import.meta as any).env?.DEV);
  const baseUrl = normalizeBaseUrl(env.BASE_URL);
  const doomProxyWorkerReady = ensureDoomRemoteProxyWorker(baseUrl, isDev);

  installAtomicsWaitAsyncGuard();

  const wasmUrl = env.VITE_WASM_URL || "./wasm/volvoxgrid_wasm.js";
  const wasmModule = await import(/* @vite-ignore */ wasmUrl);
  await wasmModule.default();
  if (typeof wasmModule.init_v1_runtime === "function") {
    try {
      wasmModule.init_v1_runtime();
    } catch (err) {
      console.warn("WASM v1 runtime init failed (continuing with legacy APIs):", err);
    }
  }
  const fontFallbacksEnabled = typeof (wasmModule as any).get_font_fallback_enabled === "function"
    ? Boolean((wasmModule as any).get_font_fallback_enabled())
    : true;

  // Canvas2D is the primary text renderer in Lite mode and a browser-font
  // fallback when remote font bytes are unavailable in the full WASM build.
  const hasBuiltinText = typeof (wasmModule as any).has_builtin_text_engine === "function"
    && (wasmModule as any).has_builtin_text_engine();
  let canvas2DRenderer: any = null;
  let useCanvas2DTextRenderer = !hasBuiltinText;
  let fullCanvas2DTextFallbackActive = false;

  const registerCanvas2DTextRenderer = (renderer: any, gridId?: number): void => {
    const wasmAny = wasmModule as any;
    const measure = renderer.measureText;
    const render = renderer.renderText;
    const cacheSize = typeof renderer.cacheSize === "function" ? renderer.cacheSize : (() => 0);
    const setCacheSize = typeof renderer.setCacheSize === "function" ? renderer.setCacheSize : (() => {});
    if (typeof gridId === "number") {
      if (typeof wasmAny.set_grid_text_renderer_with_cache === "function") {
        wasmAny.set_grid_text_renderer_with_cache(gridId, measure, render, cacheSize, setCacheSize);
      } else if (typeof wasmAny.set_grid_text_renderer === "function") {
        wasmAny.set_grid_text_renderer(gridId, measure, render);
      }
      return;
    }
    if (typeof wasmAny.set_text_renderer_with_cache === "function") {
      wasmAny.set_text_renderer_with_cache(measure, render, cacheSize, setCacheSize);
    } else if (typeof wasmAny.set_text_renderer === "function") {
      wasmAny.set_text_renderer(measure, render);
    }
  };

  const ensureCanvas2DRenderer = (): any => {
    if (canvas2DRenderer == null) {
      canvas2DRenderer = createCanvas2DTextRenderer(wasmModule, {
        fontFallbacksEnabled,
        wasm: wasmModule,
      });
    }
    canvas2DRenderer.setCacheSize(selectedTextLayoutCacheCap());
    return canvas2DRenderer;
  };

  const enableCanvas2DTextRenderer = (reason: string, gridIds: number[] = []): boolean => {
    if (hasBuiltinText && !fontFallbacksEnabled) {
      console.error(`Font fallback disabled; not using Canvas2D text fallback (${reason})`);
      return false;
    }
    const wasmAny = wasmModule as any;
    if (
      typeof wasmAny.set_text_renderer !== "function"
      && typeof wasmAny.set_text_renderer_with_cache !== "function"
    ) {
      return false;
    }
    const renderer = ensureCanvas2DRenderer();
    registerCanvas2DTextRenderer(renderer);
    for (const gridId of gridIds) {
      registerCanvas2DTextRenderer(renderer, gridId);
    }
    if (hasBuiltinText) {
      fullCanvas2DTextFallbackActive = true;
    }
    const wasAlreadyEnabled = useCanvas2DTextRenderer;
    useCanvas2DTextRenderer = true;
    if (!wasAlreadyEnabled) {
      console.warn(`Using Canvas2D text renderer fallback (${reason})`);
    }
    return true;
  };

  if (
    fontFallbacksEnabled
    && hasBuiltinText
    && typeof (wasmModule as any).set_glyph_rasterizer === "function"
  ) {
    (wasmModule as any).set_glyph_rasterizer(
      createCanvas2DRasterizer({ fontFallbacksEnabled, wasm: wasmModule }),
    );
  }

  if (!hasBuiltinText && enableCanvas2DTextRenderer("Lite mode")) {
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
  const getCurrentDeviceScale = (): number => {
    const raw = window.devicePixelRatio || 1;
    return Number.isFinite(raw) && raw > 0.01 ? raw : 1;
  };
  let layerMask = LAYER_MASK_ALL;
  const layerCheckboxes: HTMLInputElement[] = [];

  const createScaledGrid = (rows: number, cols: number): number => {
    const createGridScaled = (wasmModule as any).create_grid_scaled as
      | ((r: number, c: number, s: number) => number)
      | undefined;
    
    let id: number;
    if (typeof createGridScaled === "function") {
      id = Number(createGridScaled(rows, cols, getCurrentDeviceScale()));
    } else {
      id = Number((wasmModule as any).create_grid(rows, cols));
    }

    // Also register the external renderer for this specific grid (for measurement/auto-size)
    if (useCanvas2DTextRenderer && typeof (wasmModule as any).set_grid_text_renderer === "function") {
      const renderer = ensureCanvas2DRenderer();
      registerCanvas2DTextRenderer(renderer, id);
    }

    applyRenderLayerMaskToGrid(id);
    setGridScrollBlit(id, scrollBlitEnabled);
    setGridEditable(id, editEnabled);
    return id;
  };

  const applyAndroidLikeDemoStyle = (id: number): void => {
    if (typeof (wasmModule as any).set_font_name === "function") {
      (wasmModule as any).set_font_name(id, DEMO_DEFAULT_FONT_FAMILY);
    }
    if (typeof (wasmModule as any).set_font_size === "function") {
      (wasmModule as any).set_font_size(id, 14.0 * getCurrentDeviceScale());
    }
  };

  const grid = new VolvoxGrid(canvas, wasmModule, 2, SALES_COLS);
  if (useCanvas2DTextRenderer && typeof (wasmModule as any).set_grid_text_renderer === "function") {
    const renderer = ensureCanvas2DRenderer();
    registerCanvas2DTextRenderer(renderer, grid.id);
  }
  setupDefaultInput(grid, wasmModule, canvas);
  grid.onZoomChange = () => { updateStatus(); };
  applyAndroidLikeDemoStyle(grid.id);
  grid.captureZoomBase();
  if (typeof (wasmModule as any).get_render_layer_mask_lo === "function") {
    layerMask = normalizeLayerMask(Number((wasmModule as any).get_render_layer_mask_lo(grid.id)));
  }
  const demoFontsReady = loadDemoFontsInBackground(wasmModule).then((summary) => {
    if (hasBuiltinText && summary.missingTextFonts.length > 0) {
      if (!fontFallbacksEnabled) {
        console.error(
          `Required demo font(s) failed and font fallback is disabled: ${summary.missingTextFonts.join(", ")}`,
        );
        return summary;
      }
      const enabled = enableCanvas2DTextRenderer(
        `font download failed: ${summary.missingTextFonts.join(", ")}`,
        [grid.id],
      );
      if (enabled) {
        applyActiveRenderSettings();
        grid.invalidate();
      }
    }
    return summary;
  });

  // Prefer MAILBOX for lower-latency GPU presentation when available.
  grid.presentMode = PresentMode.PRESENT_MAILBOX;
  grid.rendererMode = RendererMode.RENDERER_GPU;
  const gpuOk = await grid.tryInitGpu();
  grid.rendererMode = RendererMode.RENDERER_CPU;

  let currentDemo: DemoMode | null = null;
  let dataRows = 0;
  const doomTouchControlsQuery = window.matchMedia("(max-width: 900px), (pointer: coarse), (hover: none)");
  const demoGridIds: Partial<Record<StandardDemoMode, number>> = {
    sales: grid.id,
  };
  const demoInitialized: Partial<Record<StandardDemoMode, boolean>> = {};
  let demoFontsResolved = false;
  const hierarchyFontAutosizedGridIds = new Set<number>();
  let activeRendererMode = RendererMode.RENDERER_CPU;
  let warnedGpuCanvasTextFallback = false;
  let scrollBlitEnabled = false;
  let editEnabled = false;
  let doomGridId: number | null = null;
  const doomRuntime = new DoomRuntime();
  let doomJoystickPointerId: number | null = null;
  let doomJoystickDirection: DoomDirectionCode | null = null;
  const resetDoomActionButtons: Array<() => void> = [];
  let switchToken = 0;
  let contextMenuEl: HTMLDivElement | null = null;
  let contextMenuDismissHandler: ((e: Event) => void) | null = null;
  let contextMenuEscHandler: ((e: KeyboardEvent) => void) | null = null;

  function dismissDebugContextMenu(): void {
    if (contextMenuEl) {
      contextMenuEl.remove();
      contextMenuEl = null;
    }
    if (contextMenuDismissHandler) {
      document.removeEventListener("pointerdown", contextMenuDismissHandler);
      contextMenuDismissHandler = null;
    }
    if (contextMenuEscHandler) {
      document.removeEventListener("keydown", contextMenuEscHandler);
      contextMenuEscHandler = null;
    }
  }

  function addDebugContextMenuItem(
    menu: HTMLDivElement,
    label: string,
    action: () => void,
  ): void {
    const item = document.createElement("div");
    item.textContent = label;
    Object.assign(item.style, {
      padding: "6px 16px",
      cursor: "pointer",
      whiteSpace: "nowrap",
    });
    item.addEventListener("pointerenter", () => {
      item.style.background = "#f0f0f0";
    });
    item.addEventListener("pointerleave", () => {
      item.style.background = "transparent";
    });
    item.addEventListener("click", () => {
      action();
      dismissDebugContextMenu();
    });
    menu.appendChild(item);
  }

  function addDebugContextMenuSeparator(menu: HTMLDivElement): void {
    const last = menu.lastElementChild;
    if (!last || (last as HTMLElement).dataset.separator === "1") {
      return;
    }
    const sep = document.createElement("div");
    sep.dataset.separator = "1";
    Object.assign(sep.style, {
      height: "1px",
      background: "#e0e0e0",
      margin: "4px 8px",
    });
    menu.appendChild(sep);
  }

  function showDebugContextMenu(request: VolvoxGridContextMenuRequest): void {
    dismissDebugContextMenu();

    const gridId = grid.id;
    const row = request.row;
    const col = request.col;
    const fixedRows = typeof (wasmModule as any).get_fixed_rows === "function"
      ? Number((wasmModule as any).get_fixed_rows(gridId))
      : 0;
    const fixedCols = typeof (wasmModule as any).get_fixed_cols === "function"
      ? Number((wasmModule as any).get_fixed_cols(gridId))
      : 0;
    const isDataRow = row >= fixedRows;
    const isDataCol = col >= fixedCols;
    const rowLabel = isDataRow ? Math.max(1, row - fixedRows + 1) : row;

    const menu = document.createElement("div");
    Object.assign(menu.style, {
      position: "fixed",
      zIndex: "2147483647",
      background: "#fff",
      border: "1px solid #ccc",
      borderRadius: "4px",
      boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
      padding: "4px 0",
      minWidth: "180px",
      fontFamily: "system-ui, -apple-system, sans-serif",
      fontSize: "13px",
      color: "#222",
      userSelect: "none",
    });

    addDebugContextMenuItem(menu, "Copy", () => {
      const text = String((wasmModule as any).copy_selection(gridId));
      if (text && navigator.clipboard) {
        void navigator.clipboard.writeText(text);
      }
    });

    if (isDataRow && row >= 0) {
      addDebugContextMenuSeparator(menu);
      const pinned = typeof (wasmModule as any).is_row_pinned === "function"
        ? Number((wasmModule as any).is_row_pinned(gridId, row))
        : 0;
      if (pinned !== 1) {
        addDebugContextMenuItem(menu, "Pin Row " + rowLabel + " to Top", () => grid.pinRow(row, 1));
      }
      if (pinned !== 2) {
        addDebugContextMenuItem(menu, "Pin Row " + rowLabel + " to Bottom", () => grid.pinRow(row, 2));
      }
      addDebugContextMenuItem(menu, "Unpin Row " + rowLabel, () => grid.pinRow(row, 0));

      addDebugContextMenuSeparator(menu);
      const stickyRow = typeof (wasmModule as any).get_row_sticky === "function"
        ? Number((wasmModule as any).get_row_sticky(gridId, row))
        : 0;
      if (stickyRow !== 1) {
        addDebugContextMenuItem(menu, "Sticky Row " + rowLabel + " to Top", () => grid.setRowSticky(row, 1));
      }
      if (stickyRow !== 2) {
        addDebugContextMenuItem(menu, "Sticky Row " + rowLabel + " to Bottom", () => grid.setRowSticky(row, 2));
      }
      if (stickyRow !== 5) {
        addDebugContextMenuItem(menu, "Sticky Row " + rowLabel + " Both", () => grid.setRowSticky(row, 5));
      }
      addDebugContextMenuItem(menu, "Unsticky Row " + rowLabel, () => grid.setRowSticky(row, 0));
    }

    if (isDataCol && col >= 0) {
      addDebugContextMenuSeparator(menu);
      const stickyCol = typeof (wasmModule as any).get_col_sticky === "function"
        ? Number((wasmModule as any).get_col_sticky(gridId, col))
        : 0;
      if (stickyCol !== 3) {
        addDebugContextMenuItem(menu, `Sticky Col ${col} to Left`, () => grid.setColSticky(col, 3));
      }
      if (stickyCol !== 4) {
        addDebugContextMenuItem(menu, `Sticky Col ${col} to Right`, () => grid.setColSticky(col, 4));
      }
      if (stickyCol !== 5) {
        addDebugContextMenuItem(menu, `Sticky Col ${col} Both`, () => grid.setColSticky(col, 5));
      }
      addDebugContextMenuItem(menu, `Unsticky Col ${col}`, () => grid.setColSticky(col, 0));
    }

    contextMenuEl = menu;
    document.body.appendChild(menu);

    let x = request.clientX;
    let y = request.clientY;
    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;
    requestAnimationFrame(() => {
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const mw = menu.offsetWidth;
      const mh = menu.offsetHeight;
      if (x + mw > vw) {
        x = Math.max(0, vw - mw - 4);
      }
      if (y + mh > vh) {
        y = Math.max(0, vh - mh - 4);
      }
      menu.style.left = `${x}px`;
      menu.style.top = `${y}px`;
    });

    window.setTimeout(() => {
      contextMenuDismissHandler = (ev: Event) => {
        if (!menu.contains(ev.target as Node)) {
          dismissDebugContextMenu();
        }
      };
      contextMenuEscHandler = (ev: KeyboardEvent) => {
        if (ev.key === "Escape") {
          dismissDebugContextMenu();
        }
      };
      document.addEventListener("pointerdown", contextMenuDismissHandler);
      document.addEventListener("keydown", contextMenuEscHandler);
    }, 0);
  }

  grid.onContextMenuRequest = showDebugContextMenu;
  let debugEventLoggingEnabled = false;

  function handleHierarchyActionClick(click: {
    row: number;
    col: number;
    hitArea: number;
    interaction: number;
  }): void {
    const message =
      "Action row " + (click.row + 1)
      + " · col " + click.col
      + " · hit_area " + click.hitArea
      + " · interaction " + click.interaction;
    updateStatus(message);
    window.alert(message);
  }

  function logDebugGridEvent(rawEvent: Uint8Array): void {
    if (!debugEventLoggingEnabled) {
      return;
    }
    try {
      const event = GridEventMessage.fromBinary(rawEvent);
      console.log("VolvoxGrid event", gridEventDebugObject(event), rawEvent);
    } catch (error) {
      console.warn("VolvoxGrid demo: failed to log grid event", error);
    }
  }

  function logDebugValidationErrors(
    source: string,
    sessionId: bigint,
    validationErrors: VolvoxGridValidationError[],
    force: boolean = false,
  ): void {
    if (!debugEventLoggingEnabled || (!force && validationErrors.length === 0)) {
      return;
    }
    console.log("VolvoxGrid validation_errors", {
      source,
      sessionId: sessionId.toString(),
      validation_errors: validationErrors,
    });
  }

  function validationErrorSummary(validationErrors: VolvoxGridValidationError[]): string {
    return validationErrors
      .map((error) => error.message || error.code)
      .filter((message) => message.length > 0)
      .join("; ");
  }

  function updateExampleValidationFeedback(
    validationErrors: VolvoxGridValidationError[],
    forceClear: boolean = false,
  ): void {
    if (validationErrors.length > 0) {
      updateStatus(`Validation: ${validationErrorSummary(validationErrors)}`);
    } else if (forceClear) {
      updateStatus();
    }
  }

  function drainHierarchyActionClickEvents(rawEvent: Uint8Array): void {
    if (currentDemo !== "hierarchy") {
      return;
    }
    const hierarchyGridId = demoGridIds.hierarchy;
    if (typeof hierarchyGridId !== "number" || grid.id !== hierarchyGridId) {
      return;
    }
    try {
      const event = GridEventMessage.fromBinary(rawEvent);
      if (event.eventCase !== GridEventEventOneofCase.Click || event.click == null) {
        return;
      }
      const click = event.click;
      if (click.row < 0
        || click.col !== HIERARCHY_ACTION_COL
        || click.hitArea !== CELL_HIT_AREA_TEXT
        || click.interaction !== CELL_INTERACTION_TEXT_LINK) {
        return;
      }
      handleHierarchyActionClick(click);
    } catch (error) {
      console.warn("VolvoxGrid demo: failed to handle click event", error);
    }
  }

  grid.onGridEventRaw = (rawEvent: Uint8Array) => {
    logDebugGridEvent(rawEvent);
    drainHierarchyActionClickEvents(rawEvent);
  };
  grid.onEditorSessionStarted = (details) => {
    logDebugValidationErrors("editor_started", details.sessionId, details.validationErrors);
    updateExampleValidationFeedback(details.validationErrors);
  };
  grid.onEditorSessionUpdated = (details) => {
    const isValidationUpdate = details.reason === EditorUpdateReason.EDITOR_UPDATE_VALIDATION;
    logDebugValidationErrors(
      "editor_updated",
      details.sessionId,
      details.validationErrors,
      isValidationUpdate,
    );
    updateExampleValidationFeedback(details.validationErrors, isValidationUpdate);
  };

  function normalizeLayerMask(raw: number): number {
    if (!Number.isFinite(raw)) {
      return LAYER_MASK_ALL;
    }
    const mask = Math.trunc(raw);
    if (mask < 0) {
      return LAYER_MASK_ALL;
    }
    return LAYER_OPTIONS.reduce(
      (normalized, layer) =>
        isLayerEnabled(mask, layer.bit) ? normalized + 2 ** layer.bit : normalized,
      0,
    );
  }

  function isLayerEnabled(mask: number, bit: number): boolean {
    if (mask < 0) {
      return true;
    }
    const flag = 2 ** bit;
    return Math.floor(mask / flag) % 2 === 1;
  }

  function setLayerBit(mask: number, bit: number, enabled: boolean): number {
    const normalized = normalizeLayerMask(mask);
    const flag = 2 ** bit;
    const currentlyEnabled = isLayerEnabled(normalized, bit);
    if (currentlyEnabled === enabled) {
      return normalized;
    }
    return enabled ? normalized + flag : normalized - flag;
  }

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

  function autoSizeHierarchyAfterFonts(id: number): void {
    if (!demoFontsResolved || !demoInitialized.hierarchy || hierarchyFontAutosizedGridIds.has(id)) {
      return;
    }

    autoSizeHierarchyColumns(grid, wasmModule, id);
    hierarchyFontAutosizedGridIds.add(id);
  }

  void demoFontsReady.then(() => {
    demoFontsResolved = true;
    const hierarchyId = demoGridIds.hierarchy;
    if (typeof hierarchyId === "number" && hierarchyId > 0) {
      autoSizeHierarchyAfterFonts(hierarchyId);
    }
  });

  function applyRenderLayerMaskToGrid(id: number): void {
    const setRenderLayerMask = (wasmModule as any).set_render_layer_mask as
      | ((gridId: number, maskHi: number, maskLo: number) => void)
      | undefined;
    if (typeof setRenderLayerMask !== "function") {
      return;
    }
    setRenderLayerMask(id, 0, layerMask);
  }

  function applyRenderLayerMaskToKnownGrids(): void {
    for (const id of knownGridIds()) {
      applyRenderLayerMaskToGrid(id);
    }
  }

  function syncLayerCheckboxes(): void {
    for (let i = 0; i < layerCheckboxes.length; i += 1) {
      layerCheckboxes[i].checked = isLayerEnabled(layerMask, LAYER_OPTIONS[i].bit);
    }
  }

  function setLayerPanelOpen(open: boolean): void {
    layerPanel.hidden = !open;
    btnLayers.setAttribute("aria-expanded", open ? "true" : "false");
    btnMobileMenu.setAttribute("aria-expanded", open ? "true" : "false");
  }

  function commitLayerMask(nextMask: number): void {
    layerMask = normalizeLayerMask(nextMask);
    syncLayerCheckboxes();
    applyRenderLayerMaskToKnownGrids();
    grid.invalidate();
  }

  function buildLayerPanel(): void {
    layerPanelOptions.replaceChildren();
    layerCheckboxes.length = 0;
    for (const layer of LAYER_OPTIONS) {
      const option = document.createElement("label");
      option.className = "layer-option";

      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = isLayerEnabled(layerMask, layer.bit);
      checkbox.addEventListener("change", () => {
        commitLayerMask(setLayerBit(layerMask, layer.bit, checkbox.checked));
      });

      const label = document.createElement("span");
      label.textContent = layer.label;

      option.append(checkbox, label);
      layerPanelOptions.append(option);
      layerCheckboxes.push(checkbox);
    }
  }

  const chkDebug = document.getElementById("chk-debug") as HTMLInputElement;
  const chkDebugMobile = document.getElementById("chk-debug-mobile") as HTMLInputElement;
  const chkGpu = document.getElementById("chk-gpu") as HTMLInputElement;
  const chkGpuMobile = document.getElementById("chk-gpu-mobile") as HTMLInputElement;
  const chkScrollBlit = document.getElementById("chk-scroll-blit") as HTMLInputElement;
  const chkScrollBlitMobile = document.getElementById("chk-scroll-blit-mobile") as HTMLInputElement;
  const chkAnim = document.getElementById("chk-anim") as HTMLInputElement;
  const chkAnimMobile = document.getElementById("chk-anim-mobile") as HTMLInputElement;
  const chkHover = document.getElementById("chk-hover") as HTMLInputElement;
  const chkHoverMobile = document.getElementById("chk-hover-mobile") as HTMLInputElement;
  const chkEdit = document.getElementById("chk-edit") as HTMLInputElement;
  const chkEditMobile = document.getElementById("chk-edit-mobile") as HTMLInputElement;
  chkScrollBlit.checked = scrollBlitEnabled;
  chkEdit.checked = editEnabled;
  chkHover.checked = parseEnvBool(env?.VITE_VG_ENABLE_HOVER, false);
  debugEventLoggingEnabled = chkDebug.checked;

  function syncMirroredCheckbox(primary: HTMLInputElement, mirror: HTMLInputElement): void {
    mirror.checked = primary.checked;
    mirror.disabled = primary.disabled;
  }

  function bindMirroredCheckbox(
    primary: HTMLInputElement,
    mirror: HTMLInputElement,
    onChange: () => void,
  ): void {
    const commit = (source: HTMLInputElement) => {
      primary.checked = source.checked;
      mirror.checked = source.checked;
      onChange();
    };
    primary.addEventListener("change", () => { commit(primary); });
    mirror.addEventListener("change", () => { commit(mirror); });
  }

  syncMirroredCheckbox(chkDebug, chkDebugMobile);
  syncMirroredCheckbox(chkGpu, chkGpuMobile);
  syncMirroredCheckbox(chkScrollBlit, chkScrollBlitMobile);
  syncMirroredCheckbox(chkAnim, chkAnimMobile);
  syncMirroredCheckbox(chkHover, chkHoverMobile);
  syncMirroredCheckbox(chkEdit, chkEditMobile);

  function hoverModeForDemo(mode: StandardDemoMode): number {
    return DEMO_DEFAULT_HOVER_MODE[mode] ?? HOVER_NONE;
  }

  function setGridHoverMode(id: number, mode: number): void {
    const prevId = grid.id;
    if (id !== prevId) {
      grid.useGrid(id);
    }
    try {
      grid.setSelectionHover({
        row: (mode & HOVER_ROW) !== 0,
        column: (mode & HOVER_COLUMN) !== 0,
        cell: (mode & HOVER_CELL) !== 0,
      });
    } catch (err) {
      console.warn("VolvoxGrid: failed to update hover mode", err);
    } finally {
      if (id !== prevId) {
        grid.useGrid(prevId);
      }
    }
  }

  function setGridScrollBlit(id: number, enabled: boolean): void {
    const setScrollBlit = (wasmModule as any).set_scroll_blit as
      | ((gridId: number, enabled: boolean) => void)
      | undefined;
    if (typeof setScrollBlit !== "function") {
      return;
    }
    setScrollBlit(id, enabled);
  }

  function setGridEditable(id: number, enabled: boolean): void {
    const setEditTrigger = (wasmModule as any).set_edit_trigger as
      | ((gridId: number, mode: number) => void)
      | undefined;
    const setEditableMode = (wasmModule as any).set_editable_mode as
      | ((gridId: number, mode: number) => void)
      | undefined;
    const mode = enabled ? EditTrigger.EDIT_TRIGGER_KEY_CLICK : EditTrigger.EDIT_TRIGGER_NONE;
    if (typeof setEditTrigger === "function") {
      setEditTrigger(id, mode);
    } else if (typeof setEditableMode === "function") {
      setEditableMode(id, mode);
    }
  }

  function applyEditableToKnownDemoGrids(): void {
    for (const mode of Object.keys(demoGridIds) as StandardDemoMode[]) {
      const id = demoGridIds[mode];
      if (typeof id !== "number" || id <= 0) {
        continue;
      }
      setGridEditable(id, editEnabled);
    }
    grid.invalidate();
  }

  function syncEditToggleEnabledState(): void {
    chkEdit.disabled = currentDemo === "doom";
    chkEditMobile.disabled = currentDemo === "doom";
  }

  function applyHoverToggleToKnownGrids(): void {
    for (const mode of Object.keys(demoGridIds) as StandardDemoMode[]) {
      const id = demoGridIds[mode];
      if (typeof id !== "number" || id <= 0) {
        continue;
      }
      setGridHoverMode(id, chkHover.checked ? hoverModeForDemo(mode) : HOVER_NONE);
    }
    if (doomGridId != null && doomGridId > 0) {
      setGridHoverMode(doomGridId, HOVER_NONE);
    }
    grid.invalidate();
  }

  function applyScrollBlitToKnownGrids(): void {
    for (const id of knownGridIds()) {
      setGridScrollBlit(id, scrollBlitEnabled);
    }
    grid.invalidate();
  }

  function selectedTextLayoutCacheCap(): number {
    const parsed = Number.parseInt(selTextCache.value, 10);
    if (Number.isFinite(parsed) && parsed >= 0) {
      return parsed;
    }
    return 8192;
  }

  function syncTextLayoutCacheSelects(value: string): void {
    for (const select of textCacheSelects) {
      if (select.value !== value) {
        select.value = value;
      }
    }
  }

  function applySelectedTextLayoutCacheCap(value: string): void {
    syncTextLayoutCacheSelects(value);
    const cap = selectedTextLayoutCacheCap();
    grid.textLayoutCacheCap = cap;
    if (canvas2DRenderer) {
      canvas2DRenderer.setCacheSize(cap);
    }
    grid.invalidate();
  }

  function applyActiveRenderSettings(): void {
    const rendererMode = fullCanvas2DTextFallbackActive && activeRendererMode === RendererMode.RENDERER_GPU
      ? RendererMode.RENDERER_CPU
      : activeRendererMode;
    if (
      rendererMode !== activeRendererMode
      && !warnedGpuCanvasTextFallback
    ) {
      warnedGpuCanvasTextFallback = true;
      console.warn("GPU rendering disabled while Canvas2D whole-text font fallback is active");
    }
    grid.rendererMode = rendererMode;
    grid.scrollBlit = scrollBlitEnabled;
    grid.debugOverlay = chkDebug.checked;
    debugEventLoggingEnabled = chkDebug.checked;
    grid.animationEnabled = chkAnim.checked;
    grid.textLayoutCacheCap = selectedTextLayoutCacheCap();
    applyRenderLayerMaskToGrid(grid.id);
  }

  const fmt = (n: number) => n.toLocaleString("en-US");
  let lastSortInfo = "";

  function colsForCurrentDemo(): number {
    switch (currentDemo) {
      case "stress": return STRESS_COLS;
      case "sales": return SALES_COLS;
      case "hierarchy": return HIERARCHY_COLS;
      case "barcodes": return BARCODE_COLS;
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
    barcodes: document.getElementById("btn-demo-barcodes")!,
    doom: document.getElementById("btn-demo-doom")!,
  };
  buildLayerPanel();
  syncLayerCheckboxes();
  syncEditToggleEnabledState();

  function setDoomOptionsVisible(visible: boolean) {
    doomRow.classList.toggle("hidden", !visible);
  }

  function shouldShowDoomTouchControls(): boolean {
    return currentDemo === "doom" && doomTouchControlsQuery.matches;
  }

  function setDoomJoystickDirection(nextDirection: DoomDirectionCode | null): void {
    if (doomJoystickDirection === nextDirection) {
      return;
    }
    if (doomJoystickDirection) {
      doomRuntime.handleKeyUp(doomJoystickDirection);
    }
    doomJoystickDirection = nextDirection;
    if (nextDirection) {
      doomRuntime.handleKeyDown(nextDirection, false);
    }
  }

  function resetDoomJoystick(): void {
    doomJoystickPointerId = null;
    setDoomJoystickDirection(null);
    doomJoystickThumb.style.transform = "translate(0px, 0px)";
    doomJoystick.classList.remove("active");
    delete doomJoystick.dataset.direction;
  }

  function resetDoomTouchControls(): void {
    resetDoomJoystick();
    for (const resetButton of resetDoomActionButtons) {
      resetButton();
    }
  }

  function updateDoomTouchControlsVisibility(): void {
    const visible = shouldShowDoomTouchControls();
    doomTouchControls.classList.toggle("show", visible);
    doomTouchControls.setAttribute("aria-hidden", visible ? "false" : "true");
    if (!visible) {
      resetDoomTouchControls();
    }
  }

  function updateDoomJoystickFromPoint(clientX: number, clientY: number): void {
    const rect = doomJoystick.getBoundingClientRect();
    const centerX = rect.left + rect.width * 0.5;
    const centerY = rect.top + rect.height * 0.5;
    const dx = clientX - centerX;
    const dy = clientY - centerY;
    const distance = Math.hypot(dx, dy);
    const deadZone = Math.max(16, rect.width * 0.14);
    const maxOffset = rect.width * 0.24;

    let thumbX = 0;
    let thumbY = 0;
    if (distance > 0) {
      const scale = Math.min(distance, maxOffset) / distance;
      thumbX = dx * scale;
      thumbY = dy * scale;
    }

    doomJoystickThumb.style.transform = `translate(${thumbX}px, ${thumbY}px)`;
    doomJoystick.classList.toggle("active", distance >= deadZone);

    if (distance < deadZone) {
      delete doomJoystick.dataset.direction;
      setDoomJoystickDirection(null);
      return;
    }

    const nextDirection: DoomDirectionCode = Math.abs(dx) >= Math.abs(dy)
      ? (dx >= 0 ? "ArrowRight" : "ArrowLeft")
      : (dy >= 0 ? "ArrowDown" : "ArrowUp");
    doomJoystick.dataset.direction = nextDirection;
    setDoomJoystickDirection(nextDirection);
  }

  function bindDoomActionButton(button: HTMLButtonElement, code: DoomTouchActionCode): void {
    let activePointerId: number | null = null;

    const release = (event: PointerEvent | null) => {
      if (activePointerId == null) {
        return;
      }
      if (event && event.pointerId !== activePointerId) {
        return;
      }
      const pointerId = activePointerId;
      activePointerId = null;
      button.classList.remove("active");
      doomRuntime.handleKeyUp(code);
      if (pointerId != null && button.hasPointerCapture(pointerId)) {
        try {
          button.releasePointerCapture(pointerId);
        } catch {
          // Ignore invalid capture transitions.
        }
      }
    };
    resetDoomActionButtons.push(() => {
      release(null);
    });

    button.addEventListener("pointerdown", (event) => {
      if (currentDemo !== "doom" || activePointerId != null) {
        return;
      }
      activePointerId = event.pointerId;
      button.classList.add("active");
      button.setPointerCapture(event.pointerId);
      doomRuntime.handleKeyDown(code, false);
      event.preventDefault();
    });
    button.addEventListener("pointerup", (event) => {
      release(event);
      event.preventDefault();
    });
    button.addEventListener("pointercancel", (event) => {
      release(event);
    });
    button.addEventListener("contextmenu", (event) => {
      event.preventDefault();
    });
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
    await doomProxyWorkerReady;
    const res = await doomRuntime.resolveAssetSource();
    if (res.ok && res.source?.id === "remote") {
      const viaProxy = res.source.bundlePath.includes("/doom/remote/");
      console.info(viaProxy
        ? "DOOM mode: using remote fallback assets via same-origin proxy."
        : "DOOM mode: using remote fallback assets from CDN.");
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
      case "barcodes":
        return BARCODE_COLS;
    }
  }

  function applyDemoViewDefaults(mode: StandardDemoMode) {
    grid.frozenRowCount = 0;
    grid.frozenColCount = mode === "sales" || mode === "stress" ? 1 : 0;
    grid.showColumnHeaders = true;
    grid.columnIndicatorTopRowCount = 1;
    grid.selectionVisibility = SelectionVisibility.SELECTION_VIS_ALWAYS;
    grid.focusBorder = FocusBorderStyle.FOCUS_BORDER_THICK;
    grid.selectionMode = SelectionMode.SELECTION_FREE;
    grid.setHeaderFeatures(
      mode === "hierarchy"
        ? { sort: false, reorder: false, chooser: false }
        : { sort: true, reorder: true, chooser: false },
    );
  }

  function applyDoomGridLayout() {
    const doomCols = doomRuntime.getCols();
    const doomRows = doomRuntime.getRows();
    grid.frozenRowCount = 0;
    grid.frozenColCount = 0;
    grid.showColumnHeaders = false;
    grid.columnIndicatorTopRowCount = 0;
    grid.showRowIndicator = false;
    grid.rowIndicatorStartWidth = 0;
    grid.selectionVisibility = SelectionVisibility.SELECTION_VIS_NONE;
    grid.focusBorder = FocusBorderStyle.FOCUS_BORDER_NONE;
    grid.selectionMode = SelectionMode.SELECTION_FREE;
    grid.setHeaderFeatures({ sort: false, reorder: false, chooser: false });
    grid.scrollBars = ScrollBarsMode.SCROLLBAR_NONE;
    grid.setGridLines(chkDoomBorder.checked ? GridLineStyle.GRIDLINE_SOLID : GridLineStyle.GRIDLINE_NONE);

    // Compute cell sizes to fill the actual render buffer.
    const cw = Math.max(1, canvas.width || Math.round(canvas.clientWidth * getCurrentDeviceScale()));
    const ch = Math.max(1, canvas.height || Math.round(canvas.clientHeight * getCurrentDeviceScale()));
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
        setupStressDemo(grid, id);
        break;
      case "sales":
        setupSalesJsonDemo(grid, id);
        break;
      case "hierarchy":
        setupHierarchyJsonDemo(grid, wasmModule, id);
        break;
      case "barcodes":
        setupBarcodesJsonDemo(grid, id);
        break;
    }

    setGridHoverMode(id, chkHover.checked ? hoverModeForDemo(mode) : HOVER_NONE);
    grid.fastScrollEnabled = true;
    applyDemoViewDefaults(mode);
    setGridEditable(id, editEnabled);
    grid.captureZoomBase();
    grid.invalidate();
    demoInitialized[mode] = true;
    if (mode === "hierarchy") {
      autoSizeHierarchyAfterFonts(id);
    }

    if (id !== prevId) {
      grid.useGrid(prevId);
    }
    return id;
  }

  function ensureDoomGridId(): number {
    if (doomGridId == null) {
      doomGridId = createScaledGrid(doomRuntime.getRows(), doomRuntime.getCols());
      setGridHoverMode(doomGridId, HOVER_NONE);
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
        status.textContent = doomRuntime.isWorkerMode()
          ? "DOOM emulator started (worker mode)."
          : "DOOM emulator started (main-thread fallback mode).";
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
      resetDoomTouchControls();
    }

    if (mode === "doom") {
      const ok = await activateDoomDemo(token);
      if (!ok || token !== switchToken) {
        return;
      }
      currentDemo = "doom";
      syncEditToggleEnabledState();
      setDoomOptionsVisible(true);
      updateDoomTouchControlsVisibility();
      highlightDemoBtn("doom");
      return;
    }

    setDoomOptionsVisible(false);
    updateDoomTouchControlsVisibility();

    const demoId = ensureDemoGrid(mode);
    if (token !== switchToken) {
      return;
    }

    grid.useGrid(demoId);
    applyActiveRenderSettings();

    currentDemo = mode;
    syncEditToggleEnabledState();
    highlightDemoBtn(mode);
    dataRows = Math.max(0, grid.rowCount - (mode === "barcodes" ? 0 : 1));

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
      case "barcodes": {
        status.textContent = "Loading Barcodes demo...";
        applyDemoViewDefaults(mode);
        break;
      }
    }
    lastSortInfo = "";
    updateStatus();

    grid.invalidate();
  }

  setDoomOptionsVisible(false);
  updateDoomTouchControlsVisibility();

  // Initial demo.
  await demoFontsReady;
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
  demoBtns.barcodes.addEventListener("click", () => {
    void switchDemo("barcodes");
  });
  demoBtns.doom.addEventListener("click", () => {
    void switchDemo("doom");
  });

  function applySelectedDoomResolution(): boolean {
    const preset = DOOM_RESOLUTIONS[selDoomRes.value];
    if (!preset) {
      return false;
    }
    doomRuntime.setResolution(preset[0], preset[1]);
    return true;
  }

  // Resolution selector.
  applySelectedDoomResolution();
  selDoomRes.addEventListener("change", () => {
    if (!applySelectedDoomResolution()) return;
    doomGridId = null;

    if (currentDemo === "doom") {
      doomRuntime.releaseAllDosKeys();
      resetDoomTouchControls();
      const token = ++switchToken;
      void activateDoomDemo(token).then((ok) => {
        if (!ok || token !== switchToken) {
          return;
        }
        currentDemo = "doom";
        setDoomOptionsVisible(true);
        updateDoomTouchControlsVisibility();
        highlightDemoBtn("doom");
      });
    }
  });

  chkDoomBorder.addEventListener("change", () => {
    if (currentDemo !== "doom") return;
    applyDoomGridLayout();
  });

  doomJoystick.addEventListener("pointerdown", (event) => {
    if (currentDemo !== "doom" || doomJoystickPointerId != null) {
      return;
    }
    doomJoystickPointerId = event.pointerId;
    doomJoystick.setPointerCapture(event.pointerId);
    updateDoomJoystickFromPoint(event.clientX, event.clientY);
    event.preventDefault();
  });

  doomJoystick.addEventListener("pointermove", (event) => {
    if (event.pointerId !== doomJoystickPointerId) {
      return;
    }
    updateDoomJoystickFromPoint(event.clientX, event.clientY);
    event.preventDefault();
  });

  const releaseDoomJoystickPointer = (event: PointerEvent) => {
    if (event.pointerId !== doomJoystickPointerId) {
      return;
    }
    const pointerId = doomJoystickPointerId;
    resetDoomJoystick();
    if (pointerId != null && doomJoystick.hasPointerCapture(pointerId)) {
      try {
        doomJoystick.releasePointerCapture(pointerId);
      } catch {
        // Ignore invalid capture transitions.
      }
    }
    event.preventDefault();
  };

  doomJoystick.addEventListener("pointerup", releaseDoomJoystickPointer);
  doomJoystick.addEventListener("pointercancel", releaseDoomJoystickPointer);
  doomJoystick.addEventListener("contextmenu", (event) => {
    event.preventDefault();
  });

  bindDoomActionButton(btnDoomFire, "ControlLeft");
  bindDoomActionButton(btnDoomUse, "Space");
  bindDoomActionButton(btnDoomSelect, "Enter");

  const handleDoomTouchEnvironmentChange = () => {
    updateDoomTouchControlsVisibility();
  };
  if (typeof doomTouchControlsQuery.addEventListener === "function") {
    doomTouchControlsQuery.addEventListener("change", handleDoomTouchEnvironmentChange);
  } else {
    doomTouchControlsQuery.addListener(handleDoomTouchEnvironmentChange);
  }

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
      resetDoomTouchControls();
    }
  });

  document.addEventListener("pointerdown", (event) => {
    const target = event.target;
    if (
      layerPanel.hidden
      || !(target instanceof Node)
      || layerDropdown.contains(target)
      || mobileMenuDropdown.contains(target)
    ) {
      return;
    }
    setLayerPanelOpen(false);
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !layerPanel.hidden) {
      setLayerPanelOpen(false);
      if (window.matchMedia("(max-width: 720px)").matches) {
        btnMobileMenu.focus();
      } else {
        btnLayers.focus();
      }
    }
  });

  // Resize handler for DOOM layout.
  let resizeTimer = 0;
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(() => {
      updateDoomTouchControlsVisibility();
      if (currentDemo === "doom") {
        applyDoomGridLayout();
      }
    }, 100);
  });

  // Toolbar handlers.
  const sortCurrentColumn = (order: 1 | 2, label: "ASC" | "DESC") => {
    const col = grid.cursorCol >= 0 ? grid.cursorCol : 0;
    const t0 = performance.now();
    grid.sort(order, col);
    const ms = (performance.now() - t0).toFixed(1);
    lastSortInfo = `Sort: col ${col} ${label} (${ms}ms)`;
    updateStatus();
  };

  btnSortAsc.addEventListener("click", () => {
    sortCurrentColumn(1, "ASC");
  });

  btnSortDesc.addEventListener("click", () => {
    sortCurrentColumn(2, "DESC");
  });

  btnSortAscMobile.addEventListener("click", () => {
    sortCurrentColumn(1, "ASC");
    setLayerPanelOpen(false);
  });

  btnSortDescMobile.addEventListener("click", () => {
    sortCurrentColumn(2, "DESC");
    setLayerPanelOpen(false);
  });

  document.getElementById("btn-sort-none")!.addEventListener("click", () => {
    const col = grid.cursorCol >= 0 ? grid.cursorCol : 0;
    grid.sort(0, col);
    grid.invalidate();
    lastSortInfo = "";
    updateStatus();
  });

  document.getElementById("btn-add-rows")!.addEventListener("click", () => {
    if (currentDemo !== "stress") return;
    dataRows += 100_000;
    grid.rowCount = dataRows + 1;
    grid.rawWasm.demo_materialize_visible_rows(grid.id, 48);
    grid.invalidate();
    updateStatus();
  });

  // AddItem: insert 5 rows at current selection.
  document.getElementById("btn-add-item")!.addEventListener("click", () => {
    if (currentDemo === "doom") return;
    const row = grid.cursorRow;
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
    const row = grid.cursorRow;
    if (row >= 0 && dataRows > 1) {
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
    grid.setHeaderFeatures({
      sort: explorerBar === 1 || explorerBar === 3,
      reorder: explorerBar === 2 || explorerBar === 3,
      chooser: false,
    });
    const labels = ["ExplBar:Off", "ExplBar:Sort", "ExplBar:Move", "ExplBar:3"];
    document.getElementById("btn-expl-bar")!.textContent = labels[explorerBar];
    grid.invalidate();
  });

  // AutoSize all columns.
  document.getElementById("btn-autosize")!.addEventListener("click", () => {
    if (currentDemo === "doom") return;
    const cols = grid.colCount;
    for (let c = 0; c < cols; c += 1) {
      grid.autoResizeCol(c);
    }
    grid.invalidate();
    status.textContent = `Auto-sized ${cols} columns`;
  });

  // GPU/CPU toggle.
  chkGpu.disabled = !gpuOk;
  chkGpuMobile.disabled = !gpuOk;
  chkGpu.checked = false;
  chkGpuMobile.checked = false;
  bindMirroredCheckbox(chkGpu, chkGpuMobile, () => {
    activeRendererMode = chkGpu.checked ? RendererMode.RENDERER_GPU : RendererMode.RENDERER_CPU;
    applyActiveRenderSettings();
    grid.invalidate();
  });

  bindMirroredCheckbox(chkScrollBlit, chkScrollBlitMobile, () => {
    scrollBlitEnabled = chkScrollBlit.checked;
    applyScrollBlitToKnownGrids();
    applyActiveRenderSettings();
    grid.invalidate();
  });

  bindMirroredCheckbox(chkEdit, chkEditMobile, () => {
    editEnabled = chkEdit.checked;
    applyEditableToKnownDemoGrids();
    if (currentDemo !== "doom") {
      updateStatus(editEnabled ? "Edit enabled" : "Edit disabled");
    }
  });

  // Animation toggle.
  bindMirroredCheckbox(chkAnim, chkAnimMobile, () => {
    applyActiveRenderSettings();
    grid.invalidate();
  });

  // Hover highlight toggle.
  bindMirroredCheckbox(chkHover, chkHoverMobile, () => {
    applyHoverToggleToKnownGrids();
  });

  btnLayers.addEventListener("click", () => {
    setLayerPanelOpen(layerPanel.hidden);
  });
  btnMobileMenu.addEventListener("click", () => {
    setLayerPanelOpen(layerPanel.hidden);
  });
  btnLayersAll.addEventListener("click", () => {
    commitLayerMask(LAYER_MASK_ALL);
  });
  btnLayersNone.addEventListener("click", () => {
    commitLayerMask(0);
  });

  // Debug overlay toggle.
  bindMirroredCheckbox(chkDebug, chkDebugMobile, () => {
    applyActiveRenderSettings();
    grid.invalidate();
  });

  // Text layout cache cap.
  for (const select of textCacheSelects) {
    select.addEventListener("change", () => {
      applySelectedTextLayoutCacheCap(select.value);
    });
  }

  // Initial options can be configured from:
  // `make web WEB_SCALE=<value> WEB_HOVER=<true|false>`
  const envZoom = Number(env?.VITE_VG_INITIAL_SCALE ?? "");
  const ZOOM_MIN = 0.3;
  const ZOOM_MAX = 3.0;
  let zoomLevel = Number.isFinite(envZoom) && envZoom > 0 ? envZoom : 1.0;
  zoomLevel = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, zoomLevel));
  grid.zoomScale = zoomLevel;
}

main().catch((err) => {
  console.error("VolvoxGrid demo failed:", err);
  const status = document.getElementById("status");
  if (status) {
    status.textContent = "Error: " + String(err);
  }
});
