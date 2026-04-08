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

import { VolvoxGrid, type VolvoxGridContextMenuRequest } from "../js/src/volvoxgrid.js";
import { setupDefaultInput } from "../js/src/default-input.js";
import { createCanvas2DTextRenderer } from "../js/src/canvas2d-text-renderer.js";
import {
  CellHitArea,
  CellInteraction,
  GridEventFields,
} from "../js/src/generated/volvoxgrid_ffi.js";
import {
  DoomRuntime,
  DOOM_LOCAL_SOURCE,
  DOOM_REMOTE_CONSENT_KEY,
  DOOM_RESOLUTIONS,
  type DoomAssetSource,
} from "./doom.js";

type DemoMode = "stress" | "sales" | "hierarchy" | "doom";
type StandardDemoMode = Exclude<DemoMode, "doom">;
type DoomDirectionCode = "ArrowUp" | "ArrowDown" | "ArrowLeft" | "ArrowRight";
type DoomTouchActionCode = "ControlLeft" | "Space" | "Enter";

const STRESS_ROWS = 1_000_000;
const STRESS_COLS = 12;
const SALES_COLS = 10;
const HIERARCHY_COLS = 6;
const SALES_STATUS_ITEMS = "Active|Pending|Shipped|Returned|Cancelled";
const GRID_EVENT_CLICK = GridEventFields["click"];
const HIERARCHY_ACTION_COL = 5;
const CELL_INTERACTION_UNSPECIFIED = CellInteraction.CELL_INTERACTION_UNSPECIFIED;
const CELL_INTERACTION_TEXT_LINK = CellInteraction.CELL_INTERACTION_TEXT_LINK;
const CELL_HIT_AREA_TEXT = CellHitArea.HIT_TEXT;
const FONT_FETCH_TIMEOUT_MS = 5000;
const DEMO_DEFAULT_FONT_FAMILY = "Roboto";
const PB_TEXT_ENCODER = new TextEncoder();
const PB_TEXT_DECODER = new TextDecoder();
const HOVER_NONE = 0;
const HOVER_ROW = 1;
const HOVER_COLUMN = 2;
const HOVER_CELL = 4;
const LAYER_NAMES = [
  "bands", "indicators", "bkgrounds", "progress", "gridlines",
  "hdr_marks", "bg_image", "borders", "text", "pictures",
  "sort", "col_drag", "checkbox", "dropdown", "selection",
  "hover", "edit_hl", "focus", "fill_hnd", "outline",
  "frozen_bd", "editor", "dd_active", "scrollbar", "fast_scrl",
  "pull_rfrsh",
  "debug_ovl",
] as const;
const LAYER_MASK_ALL = (1 << LAYER_NAMES.length) - 1;
const DEMO_DEFAULT_HOVER_MODE: Record<StandardDemoMode, number> = {
  stress: HOVER_ROW,
  sales: HOVER_ROW | HOVER_COLUMN | HOVER_CELL,
  hierarchy: HOVER_CELL,
};
const SALES_COLUMN_SETUP = [
  { caption: "Q", key: "Q", align: 4, dataType: undefined, format: undefined, dropdownItems: undefined, span: true },
  { caption: "Region", key: "Region", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: true },
  { caption: "Category", key: "Category", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Product", key: "Product", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Sales", key: "Sales", align: 7, dataType: 4, format: "$#,##0", dropdownItems: undefined, span: false },
  { caption: "Cost", key: "Cost", align: 7, dataType: 4, format: "$#,##0", dropdownItems: undefined, span: false },
  { caption: "Margin%", key: "Margin", align: 4, dataType: 1, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Flag", key: "Flag", align: 4, dataType: 3, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Status", key: "Status", align: undefined, dataType: undefined, format: undefined, dropdownItems: SALES_STATUS_ITEMS, span: false },
  { caption: "Notes", key: "Notes", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
] as const;
const HIERARCHY_COLUMN_SETUP = [
  { caption: "Name", key: "Name", width: 260, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Type", key: "Type", width: 80, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Size", key: "Size", width: 80, align: 7, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Modified", key: "Modified", width: 120, align: undefined, dataType: 2, format: "short date", dropdownItems: undefined, interaction: undefined },
  { caption: "Permissions", key: "Permissions", width: 100, align: 4, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Action", key: "Action", width: 92, align: 4, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: CellInteraction.CELL_INTERACTION_TEXT_LINK },
] as const;
type DemoColumnSetup = {
  caption: string;
  key: string;
  width?: number;
  align?: number;
  dataType?: number;
  format?: string;
  dropdownItems?: string;
  interaction?: number;
  span?: boolean;
};
type DemoFontAsset = {
  label: string;
  url: string;
};
type HierarchyDemoRow = {
  Name: string;
  Type: string;
  Size: string;
  Modified: string;
  Permissions: string;
  Action: string;
  _level: number;
};
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
): void {
  if (seenUrls.has(url)) {
    return;
  }
  seenUrls.add(url);
  fonts.push({ label, url });
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
      label: "Roboto (Latin)",
      url: "https://cdn.jsdelivr.net/gh/googlefonts/roboto-2@main/src/hinted/Roboto-Regular.ttf",
    },
  ];
  const seenUrls = new Set<string>(fonts.map((font) => font.url));
  for (const locale of locales) {
    appendDemoFontsForLocale(locale, fonts, seenUrls);
  }
  return fonts;
}

function loadDemoFontsInBackground(
  wasmModule: WasmModule,
): Promise<boolean> {
  const fonts = demoFontAssetsForLocales(browserLocaleHints());

  return Promise.all(
    fonts.map(async (font) => {
      const fontData = await fetchFontWithTimeout(font.url);
      if (fontData) {
        wasmModule.load_font(fontData);
        console.info(`Loaded demo font: ${font.label}`);
        return true;
      } else {
        console.warn(`Could not load ${font.label} - some glyphs may be missing`);
        return false;
      }
    }),
  )
    .then((results) => results.some(Boolean));
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

function pbEncodeVarint(value: bigint): number[] {
  if (value < 0n) {
    throw new RangeError("varint must be unsigned");
  }
  const out: number[] = [];
  let v = value;
  while (v >= 0x80n) {
    out.push(Number((v & 0x7fn) | 0x80n));
    v >>= 7n;
  }
  out.push(Number(v));
  return out;
}

function pbEncodeTag(field: number, wireType: number): number[] {
  return pbEncodeVarint(BigInt((field << 3) | wireType));
}

function pbEncodeMessageField(field: number, payload: Uint8Array): number[] {
  return [
    ...pbEncodeTag(field, 2),
    ...pbEncodeVarint(BigInt(payload.length)),
    ...payload,
  ];
}

function pbEncodeBool(value: boolean): number[] {
  return pbEncodeVarint(value ? 1n : 0n);
}

function pbEncodeInt32(value: number): number[] {
  const i32 = BigInt.asIntN(32, BigInt(Math.trunc(value)));
  return pbEncodeVarint(BigInt.asUintN(64, i32));
}

function pbEncodeStringField(field: number, value: string): number[] {
  const bytes = PB_TEXT_ENCODER.encode(value);
  return [
    ...pbEncodeTag(field, 2),
    ...pbEncodeVarint(BigInt(bytes.length)),
    ...bytes,
  ];
}

function pbEncodeInt32Field(field: number, value: number): number[] {
  return [...pbEncodeTag(field, 0), ...pbEncodeInt32(value)];
}

function pbEncodeUint32Field(field: number, value: number): number[] {
  return [...pbEncodeTag(field, 0), ...pbEncodeVarint(BigInt(value >>> 0))];
}

function pbEncodeFloatField(field: number, value: number): number[] {
  const buf = new ArrayBuffer(4);
  new DataView(buf).setFloat32(0, value, true);
  return [...pbEncodeTag(field, 5), ...Array.from(new Uint8Array(buf))];
}

function pbEncodeBorder(style: number, color: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(1, style));
  out.push(...pbEncodeUint32Field(2, color));
  return new Uint8Array(out);
}

function pbEncodeBordersAll(style: number, color: number): Uint8Array {
  return new Uint8Array(pbEncodeMessageField(1, pbEncodeBorder(style, color)));
}

function pbEncodeGridLinesPayload(color: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(1, 1));
  out.push(...pbEncodeUint32Field(3, color));
  return new Uint8Array(out);
}

function pbEncodeRegionStylePayload(background: number, foreground: number, gridColor: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeUint32Field(1, background));
  out.push(...pbEncodeUint32Field(2, foreground));
  out.push(...pbEncodeMessageField(4, pbEncodeGridLinesPayload(gridColor)));
  return new Uint8Array(out);
}

function pbEncodeHeaderStylePayload(color: number): Uint8Array {
  const separator: number[] = [];
  separator.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  separator.push(...pbEncodeUint32Field(2, color));
  separator.push(...pbEncodeInt32Field(3, 1));

  const resizeHandle: number[] = [];
  resizeHandle.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  resizeHandle.push(...pbEncodeUint32Field(2, color));
  resizeHandle.push(...pbEncodeInt32Field(3, 1));
  resizeHandle.push(...pbEncodeInt32Field(5, 6));

  const out: number[] = [];
  out.push(...pbEncodeMessageField(1, new Uint8Array(separator)));
  out.push(...pbEncodeMessageField(2, new Uint8Array(resizeHandle)));
  return new Uint8Array(out);
}

function pbEncodeHighlightStylePayload(options: {
  background?: number;
  foreground?: number;
  borderStyle?: number;
  borderColor?: number;
  fillHandle?: number;
  fillHandleColor?: number;
}): Uint8Array {
  const out: number[] = [];
  if (options.background != null) {
    out.push(...pbEncodeUint32Field(1, options.background));
  }
  if (options.foreground != null) {
    out.push(...pbEncodeUint32Field(2, options.foreground));
  }
  if (options.borderStyle != null && options.borderColor != null) {
    out.push(...pbEncodeMessageField(3, pbEncodeBordersAll(options.borderStyle, options.borderColor)));
  }
  if (options.fillHandle != null) {
    out.push(...pbEncodeInt32Field(4, options.fillHandle));
  }
  if (options.fillHandleColor != null) {
    out.push(...pbEncodeUint32Field(5, options.fillHandleColor));
  }
  return new Uint8Array(out);
}

function pbEncodeColumnDef(
  index: number,
  setup: DemoColumnSetup,
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(1, index));
  if (setup.width != null) {
    out.push(...pbEncodeInt32Field(2, setup.width));
  }
  out.push(...pbEncodeStringField(5, setup.caption));
  if (setup.align != null) {
    out.push(...pbEncodeInt32Field(6, setup.align));
  }
  if (setup.dataType != null) {
    out.push(...pbEncodeInt32Field(8, setup.dataType));
  }
  if (setup.format != null) {
    out.push(...pbEncodeStringField(9, setup.format));
  }
  out.push(...pbEncodeStringField(10, setup.key));
  if (setup.dropdownItems != null) {
    out.push(...pbEncodeStringField(13, setup.dropdownItems));
  }
  if (setup.span != null) {
    out.push(...pbEncodeTag(17, 0), ...pbEncodeBool(setup.span));
  }
  if (setup.interaction != null) {
    out.push(...pbEncodeInt32Field(26, setup.interaction));
  }
  return new Uint8Array(out);
}

function pbEncodeDefineColumnsRequest(gridId: number, columns: readonly DemoColumnSetup[]): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeVarint(BigInt(gridId)));
  columns.forEach((column, index) => {
    out.push(...pbEncodeMessageField(2, pbEncodeColumnDef(index, column)));
  });
  return new Uint8Array(out);
}

function pbEncodeRowDef(index: number, outlineLevel: number, isSubtotal: boolean): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(1, index));
  out.push(...pbEncodeTag(4, 0), ...pbEncodeBool(isSubtotal));
  out.push(...pbEncodeInt32Field(5, outlineLevel));
  return new Uint8Array(out);
}

function pbEncodeDefineRowsRequest(
  gridId: number,
  rows: ReadonlyArray<{ outlineLevel: number; isSubtotal: boolean }>,
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeVarint(BigInt(gridId)));
  rows.forEach((row, index) => {
    out.push(...pbEncodeMessageField(2, pbEncodeRowDef(index, row.outlineLevel, row.isSubtotal)));
  });
  return new Uint8Array(out);
}

function pbEncodeHierarchyOutlineConfig(): Uint8Array {
  const layout: number[] = [];
  layout.push(...pbEncodeInt32Field(3, 0));

  const style: number[] = [];
  style.push(...pbEncodeUint32Field(1, 0xFFFFFFFF));
  style.push(...pbEncodeUint32Field(2, 0xFF1C1917));
  style.push(...pbEncodeUint32Field(3, 0xFFF5F5F4));
  style.push(...pbEncodeUint32Field(7, 0xFFF59E0B));
  style.push(...pbEncodeMessageField(10, pbEncodeGridLinesPayload(0xFFE7E5E4)));
  style.push(...pbEncodeMessageField(11, pbEncodeRegionStylePayload(0xFFF5F5F4, 0xFF44403C, 0xFFD6D3D1)));
  style.push(...pbEncodeMessageField(12, pbEncodeRegionStylePayload(0xFFFFFFFF, 0xFF1C1917, 0xFFD6D3D1)));
  style.push(...pbEncodeMessageField(13, pbEncodeHeaderStylePayload(0xFFD6D3D1)));
  style.push(...pbEncodeUint32Field(20, 0xFFFAFAF9));
  style.push(...pbEncodeUint32Field(21, 0xFFD6D3D1));

  const selectionStyle = pbEncodeHighlightStylePayload({
    background: 0xFFD97706,
    foreground: 0xFFFFFFFF,
    fillHandle: 0,
    fillHandleColor: 0xFFF59E0B,
  });
  const activeCellStyle = pbEncodeHighlightStylePayload({
    background: 0x22000000,
    foreground: 0xFFFFFFFF,
    borderStyle: 2,
    borderColor: 0xFFF59E0B,
  });
  const hover: number[] = [];
  hover.push(...pbEncodeTag(3, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeMessageField(6, pbEncodeHighlightStylePayload({
    background: 0x1AD97706,
    borderStyle: 1,
    borderColor: 0xFFF59E0B,
  })));
  const selection: number[] = [];
  selection.push(...pbEncodeInt32Field(1, 0));
  selection.push(...pbEncodeMessageField(6, selectionStyle));
  selection.push(...pbEncodeMessageField(7, new Uint8Array(hover)));
  selection.push(...pbEncodeMessageField(10, activeCellStyle));

  const editing: number[] = [];
  editing.push(...pbEncodeInt32Field(1, 0));
  editing.push(...pbEncodeInt32Field(2, 1));
  editing.push(...pbEncodeInt32Field(3, 0));

  const scrolling: number[] = [];
  scrolling.push(...pbEncodeInt32Field(9, 3));
  scrolling.push(...pbEncodeTag(4, 0), ...pbEncodeBool(true));
  scrolling.push(...pbEncodeFloatField(5, 220.0));
  scrolling.push(...pbEncodeFloatField(6, 0.9));

  const outline: number[] = [];
  outline.push(...pbEncodeInt32Field(1, 2));
  outline.push(...pbEncodeInt32Field(2, 0));
  outline.push(...pbEncodeUint32Field(3, 0xFFA8A29E));

  const resize: number[] = [];
  resize.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  resize.push(...pbEncodeTag(2, 0), ...pbEncodeBool(true));
  const freeze: number[] = [];
  freeze.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  freeze.push(...pbEncodeTag(2, 0), ...pbEncodeBool(true));
  const headerFeatures: number[] = [];
  headerFeatures.push(...pbEncodeTag(1, 0), ...pbEncodeBool(false));
  headerFeatures.push(...pbEncodeTag(2, 0), ...pbEncodeBool(false));
  headerFeatures.push(...pbEncodeTag(3, 0), ...pbEncodeBool(false));
  const interaction: number[] = [];
  interaction.push(...pbEncodeMessageField(1, new Uint8Array(resize)));
  interaction.push(...pbEncodeMessageField(2, new Uint8Array(freeze)));
  interaction.push(...pbEncodeTag(5, 0), ...pbEncodeBool(true));
  interaction.push(...pbEncodeMessageField(10, new Uint8Array(headerFeatures)));

  const colTop: number[] = [];
  colTop.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  colTop.push(...pbEncodeInt32Field(2, 28));
  colTop.push(...pbEncodeInt32Field(3, 1));
  colTop.push(...pbEncodeTag(4, 0), ...pbEncodeVarint(1n));
  colTop.push(...pbEncodeUint32Field(5, 0xFFFAFAF9));
  colTop.push(...pbEncodeUint32Field(6, 0xFF1C1917));
  colTop.push(...pbEncodeUint32Field(8, 0xFFD6D3D1));
  colTop.push(...pbEncodeTag(10, 0), ...pbEncodeBool(true));
  const rowStart: number[] = [];
  rowStart.push(...pbEncodeTag(1, 0), ...pbEncodeBool(false));
  const indicators: number[] = [];
  indicators.push(...pbEncodeMessageField(3, new Uint8Array(colTop)));
  indicators.push(...pbEncodeMessageField(1, new Uint8Array(rowStart)));
  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(1, new Uint8Array(layout)));
  gridConfig.push(...pbEncodeMessageField(2, new Uint8Array(style)));
  gridConfig.push(...pbEncodeMessageField(3, new Uint8Array(selection)));
  gridConfig.push(...pbEncodeMessageField(4, new Uint8Array(editing)));
  gridConfig.push(...pbEncodeMessageField(5, new Uint8Array(scrolling)));
  gridConfig.push(...pbEncodeMessageField(6, new Uint8Array(outline)));
  gridConfig.push(...pbEncodeMessageField(8, new Uint8Array(interaction)));
  gridConfig.push(...pbEncodeMessageField(11, new Uint8Array(indicators)));
  return new Uint8Array(gridConfig);
}

function pbEncodeSalesDemoConfig(): Uint8Array {
  const layout: number[] = [];
  layout.push(...pbEncodeInt32Field(3, 0));
  layout.push(...pbEncodeTag(10, 0), ...pbEncodeBool(true));

  const style: number[] = [];
  style.push(...pbEncodeUint32Field(1, 0xFFFFFFFF));
  style.push(...pbEncodeUint32Field(2, 0xFF111827));
  style.push(...pbEncodeUint32Field(3, 0xFFF9FAFB));
  style.push(...pbEncodeUint32Field(7, 0xFF818CF8));
  style.push(...pbEncodeMessageField(10, pbEncodeGridLinesPayload(0xFFE5E7EB)));
  style.push(...pbEncodeMessageField(11, pbEncodeRegionStylePayload(0xFFF3F4F6, 0xFF374151, 0xFFD1D5DB)));
  style.push(...pbEncodeMessageField(12, pbEncodeRegionStylePayload(0xFFFFFFFF, 0xFF111827, 0xFFD1D5DB)));
  style.push(...pbEncodeMessageField(13, pbEncodeHeaderStylePayload(0xFFD1D5DB)));
  style.push(...pbEncodeUint32Field(20, 0xFFFAFAFB));
  style.push(...pbEncodeUint32Field(21, 0xFFD1D5DB));

  const selectionStyle = pbEncodeHighlightStylePayload({
    background: 0xFF6366F1,
    foreground: 0xFFFFFFFF,
    fillHandle: 0,
    fillHandleColor: 0xFF818CF8,
  });
  const activeCellStyle = pbEncodeHighlightStylePayload({
    background: 0x22000000,
    foreground: 0xFFFFFFFF,
    borderStyle: 2,
    borderColor: 0xFF818CF8,
  });
  const hover: number[] = [];
  hover.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeTag(2, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeTag(3, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeMessageField(4, pbEncodeHighlightStylePayload({ background: 0x106366F1 })));
  hover.push(...pbEncodeMessageField(5, pbEncodeHighlightStylePayload({ background: 0x106366F1 })));
  hover.push(...pbEncodeMessageField(6, pbEncodeHighlightStylePayload({
    background: 0x1E818CF8,
    borderStyle: 1,
    borderColor: 0xFF818CF8,
  })));
  const selection: number[] = [];
  selection.push(...pbEncodeInt32Field(1, 0));
  selection.push(...pbEncodeMessageField(6, selectionStyle));
  selection.push(...pbEncodeMessageField(7, new Uint8Array(hover)));
  selection.push(...pbEncodeMessageField(10, activeCellStyle));

  const editing: number[] = [];
  editing.push(...pbEncodeInt32Field(1, 0));
  editing.push(...pbEncodeInt32Field(2, 1));
  editing.push(...pbEncodeInt32Field(3, 1));
  editing.push(...pbEncodeTag(4, 0), ...pbEncodeBool(false));

  const scrolling: number[] = [];
  scrolling.push(...pbEncodeInt32Field(9, 3));
  scrolling.push(...pbEncodeTag(4, 0), ...pbEncodeBool(true));
  scrolling.push(...pbEncodeFloatField(5, 220.0));
  scrolling.push(...pbEncodeFloatField(6, 0.9));

  const outline: number[] = [];
  outline.push(...pbEncodeInt32Field(1, 0));
  outline.push(...pbEncodeInt32Field(4, 1));
  outline.push(...pbEncodeTag(5, 0), ...pbEncodeBool(true));
  outline.push(...pbEncodeUint32Field(3, 0xFF9CA3AF));

  const span: number[] = [];
  span.push(...pbEncodeInt32Field(1, 2));
  span.push(...pbEncodeInt32Field(2, 0));
  span.push(...pbEncodeInt32Field(3, 1));

  const resize: number[] = [];
  resize.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  resize.push(...pbEncodeTag(2, 0), ...pbEncodeBool(true));
  const freeze: number[] = [];
  freeze.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  freeze.push(...pbEncodeTag(2, 0), ...pbEncodeBool(true));
  const headerFeatures: number[] = [];
  headerFeatures.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  headerFeatures.push(...pbEncodeTag(2, 0), ...pbEncodeBool(true));
  headerFeatures.push(...pbEncodeTag(3, 0), ...pbEncodeBool(false));
  const interaction: number[] = [];
  interaction.push(...pbEncodeMessageField(1, new Uint8Array(resize)));
  interaction.push(...pbEncodeMessageField(2, new Uint8Array(freeze)));
  interaction.push(...pbEncodeTag(5, 0), ...pbEncodeBool(true));
  interaction.push(...pbEncodeMessageField(10, new Uint8Array(headerFeatures)));

  const rowStart: number[] = [];
  rowStart.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  rowStart.push(...pbEncodeInt32Field(2, 40));
  rowStart.push(...pbEncodeTag(3, 0), ...pbEncodeVarint(1n));
  rowStart.push(...pbEncodeUint32Field(4, 0xFFF9FAFB));
  rowStart.push(...pbEncodeUint32Field(5, 0xFF6B7280));
  rowStart.push(...pbEncodeUint32Field(7, 0xFFD1D5DB));
  rowStart.push(...pbEncodeTag(9, 0), ...pbEncodeBool(true));
  const colTop: number[] = [];
  colTop.push(...pbEncodeTag(1, 0), ...pbEncodeBool(true));
  colTop.push(...pbEncodeInt32Field(2, 28));
  colTop.push(...pbEncodeInt32Field(3, 1));
  colTop.push(...pbEncodeTag(4, 0), ...pbEncodeVarint(3n));
  colTop.push(...pbEncodeUint32Field(5, 0xFFF9FAFB));
  colTop.push(...pbEncodeUint32Field(6, 0xFF111827));
  colTop.push(...pbEncodeUint32Field(8, 0xFFD1D5DB));
  colTop.push(...pbEncodeTag(10, 0), ...pbEncodeBool(true));
  const indicators: number[] = [];
  indicators.push(...pbEncodeMessageField(1, new Uint8Array(rowStart)));
  indicators.push(...pbEncodeMessageField(3, new Uint8Array(colTop)));
  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(1, new Uint8Array(layout)));
  gridConfig.push(...pbEncodeMessageField(2, new Uint8Array(style)));
  gridConfig.push(...pbEncodeMessageField(3, new Uint8Array(selection)));
  gridConfig.push(...pbEncodeMessageField(4, new Uint8Array(editing)));
  gridConfig.push(...pbEncodeMessageField(5, new Uint8Array(scrolling)));
  gridConfig.push(...pbEncodeMessageField(6, new Uint8Array(outline)));
  gridConfig.push(...pbEncodeMessageField(7, new Uint8Array(span)));
  gridConfig.push(...pbEncodeMessageField(8, new Uint8Array(interaction)));
  gridConfig.push(...pbEncodeMessageField(11, new Uint8Array(indicators)));
  return new Uint8Array(gridConfig);
}

function applySalesSubtotalDecorations(grid: VolvoxGrid, subtotalRows: readonly number[]): void {
  const uniqueRows = [...new Set(subtotalRows)].sort((a, b) => a - b);
  for (const row of uniqueRows) {
    const node = grid.getNode(row);
    if (node != null && node.level <= 0) {
      grid.mergeCells(row, 0, row, 1);
    }
  }
}

function setupSalesJsonDemo(grid: VolvoxGrid, wasmModule: WasmModule, id: number): void {
  const prevId = grid.id;
  if (id !== prevId) {
    grid.useGrid(id);
  }

  try {
    const salesData = grid.getDemoData("sales");
    if (salesData.length === 0) {
      throw new Error("embedded sales demo data is empty");
    }
    const gridHandle = BigInt(id);
    grid.colCount = SALES_COLS;
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, SALES_COLUMN_SETUP));
    const result = grid.loadData(salesData, { autoCreateColumns: false });
    if (result.status === 2) {
      throw new Error("LoadData failed for embedded sales demo");
    }
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, SALES_COLUMN_SETUP));
    if (typeof wasmModule.volvox_grid_configure === "function") {
      wasmModule.volvox_grid_configure(gridHandle, pbEncodeSalesDemoConfig());
    }
    grid.selectionMode = 0;
    grid.dropdownTrigger = 1;
    grid.dropdownSearch = false;
    grid.setHeaderFeatures({ sort: true, reorder: true, chooser: false });
    grid.setColFormat(4, "$#,##0");
    grid.setColFormat(5, "$#,##0");
    grid.setColProgressColor(6, 0xFF818CF8);
    grid.setColDropdownItems(8, SALES_STATUS_ITEMS);
    grid.flingImpulseGain = 220.0;
    grid.flingFriction = 0.9;
    grid.subtotal(1, 0, 0, "", 0, 0, false);
    applySalesSubtotalDecorations(grid, grid.subtotal(2, -1, 4, "Grand Total", 0xFFEEF2FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(2, 0, 4, "", 0xFFF5F3FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(2, 1, 4, "", 0xFFF8F7FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(2, -1, 5, "Grand Total", 0xFFEEF2FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(2, 0, 5, "", 0xFFF5F3FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(2, 1, 5, "", 0xFFF8F7FF, 0xFF111827, true).rows);
    grid.invalidate();
  } finally {
    if (id !== prevId) {
      grid.useGrid(prevId);
    }
  }
}

function setupHierarchyJsonDemo(grid: VolvoxGrid, wasmModule: WasmModule, id: number): void {
  const prevId = grid.id;
  if (id !== prevId) {
    grid.useGrid(id);
  }

  try {
    const rawHierarchy = grid.getDemoData("hierarchy");
    if (rawHierarchy.length === 0) {
      throw new Error("embedded hierarchy demo data is empty");
    }
    const rawRows = JSON.parse(PB_TEXT_DECODER.decode(rawHierarchy)) as HierarchyDemoRow[];
    const loadRows = rawRows.map(({ _level, ...row }) => row);
    grid.colCount = HIERARCHY_COLS;
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, HIERARCHY_COLUMN_SETUP));
    const result = grid.loadData(PB_TEXT_ENCODER.encode(JSON.stringify(loadRows)), {
      autoCreateColumns: false,
    });
    if (result.status === 2) {
      throw new Error("LoadData failed for embedded hierarchy demo");
    }
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, HIERARCHY_COLUMN_SETUP));
    wasmModule.volvox_grid_define_rows_pb(
      pbEncodeDefineRowsRequest(
        id,
        rawRows.map((row) => ({
          outlineLevel: Math.trunc(row._level),
          isSubtotal: row.Type === "Folder",
        })),
      ),
    );
    if (typeof wasmModule.volvox_grid_configure === "function") {
      wasmModule.volvox_grid_configure(BigInt(id), pbEncodeHierarchyOutlineConfig());
    }

    grid.selectionMode = 0;
    grid.setHeaderFeatures({ sort: false, reorder: false, chooser: false });
    grid.flingImpulseGain = 220.0;
    grid.flingFriction = 0.9;
    grid.editable = false;
    rawRows.forEach((row, index) => {
      grid.setCellStyle(index, 5, { foreground: 0xFF2563EB });
      if (row.Type === "Folder") {
        grid.setCellStyle(index, 0, {
          foreground: 0xFF92400E,
          font: { bold: true },
        });
      }
    });
    grid.invalidate();
  } finally {
    if (id !== prevId) {
      grid.useGrid(prevId);
    }
  }
}

function pbEncodeSelectionHoverConfig(mode: number): Uint8Array {
  const nextMode = Number.isFinite(mode) ? (Math.max(0, Math.trunc(mode)) >>> 0) : 0;
  const hoverConfig: number[] = [];
  hoverConfig.push(...pbEncodeTag(1, 0), ...pbEncodeVarint((nextMode & HOVER_ROW) !== 0 ? 1n : 0n));
  hoverConfig.push(...pbEncodeTag(2, 0), ...pbEncodeVarint((nextMode & HOVER_COLUMN) !== 0 ? 1n : 0n));
  hoverConfig.push(...pbEncodeTag(3, 0), ...pbEncodeVarint((nextMode & HOVER_CELL) !== 0 ? 1n : 0n));
  const selectionConfig: number[] = [];
  // SelectionConfig.hover = 7
  selectionConfig.push(...pbEncodeMessageField(7, new Uint8Array(hoverConfig)));

  const gridConfig: number[] = [];
  // GridConfig.selection = 3
  gridConfig.push(...pbEncodeMessageField(3, new Uint8Array(selectionConfig)));
  return new Uint8Array(gridConfig);
}

function pbReadVarint(data: Uint8Array, offset: number): { value: bigint; next: number } {
  let value = 0n;
  let shift = 0n;
  let index = offset;
  while (index < data.length) {
    const byte = BigInt(data[index]);
    index += 1;
    value |= (byte & 0x7fn) << shift;
    if ((byte & 0x80n) === 0n) {
      return { value, next: index };
    }
    shift += 7n;
  }
  return { value, next: data.length };
}

function pbSkipField(data: Uint8Array, offset: number, wireType: number): number {
  if (wireType === 0) {
    return pbReadVarint(data, offset).next;
  }
  if (wireType === 2) {
    const len = pbReadVarint(data, offset);
    return Math.min(data.length, len.next + Number(len.value));
  }
  return data.length;
}

function pbAsInt32(value: bigint): number {
  return Number(BigInt.asIntN(32, value));
}

function pbDecodeGridEventEnvelope(
  data: Uint8Array,
): { eventField: number; payload: Uint8Array } | null {
  let offset = 0;
  let eventField = 0;
  let payload = new Uint8Array(0);
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);

    if (wire === 2 && field >= 2 && field <= 60) {
      const len = pbReadVarint(data, offset);
      const size = Number(len.value);
      if (!Number.isFinite(size) || size < 0) {
        return null;
      }
      const start = len.next;
      const end = Math.min(data.length, start + size);
      eventField = field;
      payload = data.slice(start, end);
      offset = end;
      continue;
    }

    offset = pbSkipField(data, offset, wire);
  }

  return eventField === 0 ? null : { eventField, payload };
}

function pbDecodeClickEventPayload(
  data: Uint8Array,
): { row: number; col: number; hitArea: number; interaction: number } {
  let row = 0;
  let col = 0;
  let hitArea = 0;
  let interaction = CELL_INTERACTION_UNSPECIFIED;
  let offset = 0;
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const value = pbReadVarint(data, offset);
      const n = pbAsInt32(value.value);
      offset = value.next;
      if (field === 1) row = n;
      if (field === 2) col = n;
      if (field === 3) hitArea = n;
      if (field === 4) interaction = n;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return { row, col, hitArea, interaction };
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
  const layerDropdown = document.getElementById("layer-dropdown") as HTMLDivElement;
  const btnLayers = document.getElementById("btn-layers") as HTMLButtonElement;
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
  let layerMask = LAYER_MASK_ALL;
  const layerCheckboxes: HTMLInputElement[] = [];

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
  if (typeof (wasmModule as any).get_render_layer_mask_lo === "function") {
    layerMask = normalizeLayerMask(Number((wasmModule as any).get_render_layer_mask_lo(grid.id)));
  }
  const demoFontsReady = loadDemoFontsInBackground(wasmModule);

  // PresentMode (proto): 0=AUTO, 1=FIFO, 2=MAILBOX, 3=IMMEDIATE.
  // Prefer MAILBOX for lower-latency GPU presentation when available.
  grid.presentMode = 2;
  grid.rendererMode = 2; // GPU — let tryInitGpu proceed
  const gpuOk = await grid.tryInitGpu();
  grid.rendererMode = 1; // default CPU

  let currentDemo: DemoMode | null = null;
  let dataRows = 0;
  const doomTouchControlsQuery = window.matchMedia("(max-width: 900px), (pointer: coarse), (hover: none)");
  const demoGridIds: Partial<Record<StandardDemoMode, number>> = {
    sales: grid.id,
  };
  const demoInitialized: Partial<Record<StandardDemoMode, boolean>> = {};
  let activeRendererMode = 1; // CPU
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

  function drainHierarchyActionClickEvents(rawEvent: Uint8Array): void {
    if (currentDemo !== "hierarchy") {
      return;
    }
    const hierarchyGridId = demoGridIds.hierarchy;
    if (typeof hierarchyGridId !== "number" || grid.id !== hierarchyGridId) {
      return;
    }
    try {
      const decoded = pbDecodeGridEventEnvelope(rawEvent);
      if (decoded == null || decoded.eventField !== GRID_EVENT_CLICK) {
        return;
      }
      const click = pbDecodeClickEventPayload(decoded.payload);
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

  grid.onGridEventRaw = drainHierarchyActionClickEvents;

  function normalizeLayerMask(raw: number): number {
    if (!Number.isFinite(raw)) {
      return LAYER_MASK_ALL;
    }
    return Math.trunc(raw) & LAYER_MASK_ALL;
  }

  function isLayerEnabled(mask: number, bit: number): boolean {
    return ((mask >>> bit) & 1) === 1;
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
      layerCheckboxes[i].checked = isLayerEnabled(layerMask, i);
    }
  }

  function setLayerPanelOpen(open: boolean): void {
    layerPanel.hidden = !open;
    btnLayers.setAttribute("aria-expanded", open ? "true" : "false");
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
    for (let i = 0; i < LAYER_NAMES.length; i += 1) {
      const option = document.createElement("label");
      option.className = "layer-option";

      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = isLayerEnabled(layerMask, i);
      checkbox.addEventListener("change", () => {
        const bit = 1 << i;
        commitLayerMask(checkbox.checked ? (layerMask | bit) : (layerMask & ~bit));
      });

      const label = document.createElement("span");
      label.textContent = LAYER_NAMES[i];

      option.append(checkbox, label);
      layerPanelOptions.append(option);
      layerCheckboxes.push(checkbox);
    }
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
  const chkScrollBlit = document.getElementById("chk-scroll-blit") as HTMLInputElement;
  const chkAnim = document.getElementById("chk-anim") as HTMLInputElement;
  const chkHover = document.getElementById("chk-hover") as HTMLInputElement;
  const chkEdit = document.getElementById("chk-edit") as HTMLInputElement;
  chkScrollBlit.checked = scrollBlitEnabled;
  chkEdit.checked = editEnabled;
  chkHover.checked = parseEnvBool(env?.VITE_VG_ENABLE_HOVER, false);

  function hoverModeForDemo(mode: StandardDemoMode): number {
    return DEMO_DEFAULT_HOVER_MODE[mode] ?? HOVER_NONE;
  }

  function setGridHoverMode(id: number, mode: number): void {
    const configure = (wasmModule as any).volvox_grid_configure as
      | ((gridId: bigint, config: Uint8Array) => Uint8Array)
      | undefined;
    if (typeof configure !== "function") {
      return;
    }
    try {
      configure(BigInt(Math.trunc(id)), pbEncodeSelectionHoverConfig(mode));
    } catch (err) {
      console.warn("VolvoxGrid: failed to update hover mode", err);
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
    const mode = enabled ? 2 : 0;
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

  function applyActiveRenderSettings(): void {
    grid.rendererMode = activeRendererMode;
    grid.scrollBlit = scrollBlitEnabled;
    grid.debugOverlay = chkDebug.checked;
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
        ? "DOOM mode: using remote fallback assets via dev proxy."
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
    }
  }

  function applyDemoViewDefaults(mode: StandardDemoMode) {
    grid.frozenRowCount = 0;
    grid.frozenColCount = mode === "hierarchy" ? 0 : 1;
    grid.showColumnHeaders = true;
    grid.columnIndicatorTopRowCount = 1;
    grid.selectionVisibility = 1;
    grid.focusBorder = 2;
    grid.selectionMode = 0;
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
    grid.selectionVisibility = 0;
    grid.focusBorder = 0;
    grid.selectionMode = 0;
    grid.setHeaderFeatures({ sort: false, reorder: false, chooser: false });
    grid.scrollBars = 0;
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
        setupSalesJsonDemo(grid, wasmModule, id);
        break;
      case "hierarchy":
        setupHierarchyJsonDemo(grid, wasmModule, id);
        break;
    }

    setGridHoverMode(id, chkHover.checked ? hoverModeForDemo(mode) : HOVER_NONE);
    wasmModule.set_fast_scroll_enabled(id, true);
    applyDemoViewDefaults(mode);
    setGridEditable(id, editEnabled);
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
    dataRows = Math.max(0, grid.rowCount - 1);

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
  updateDoomTouchControlsVisibility();

  rebuildCanvasResolutionOptions(false);
  selCanvasRes.addEventListener("change", () => {
    applyCanvasResolutionPreset(selCanvasRes.value);
  });
  applyCanvasResolutionPreset(selCanvasRes.value);

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
    if (layerPanel.hidden || !(target instanceof Node) || layerDropdown.contains(target)) {
      return;
    }
    setLayerPanelOpen(false);
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !layerPanel.hidden) {
      setLayerPanelOpen(false);
      btnLayers.focus();
    }
  });

  // Resize handler for DOOM layout.
  let resizeTimer = 0;
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(() => {
      rebuildCanvasResolutionOptions(true);
      applyCanvasResolutionPreset(selCanvasRes.value);
      updateDoomTouchControlsVisibility();
      if (currentDemo === "doom") {
        applyDoomGridLayout();
      }
    }, 100);
  });

  // Toolbar handlers.
  document.getElementById("btn-sort-asc")!.addEventListener("click", () => {
    const col = grid.cursorCol >= 0 ? grid.cursorCol : 0;
    const t0 = performance.now();
    grid.sort(1, col);
    const ms = (performance.now() - t0).toFixed(1);
    lastSortInfo = `Sort: col ${col} ASC (${ms}ms)`;
    updateStatus();
  });

  document.getElementById("btn-sort-desc")!.addEventListener("click", () => {
    const col = grid.cursorCol >= 0 ? grid.cursorCol : 0;
    const t0 = performance.now();
    grid.sort(2, col);
    const ms = (performance.now() - t0).toFixed(1);
    lastSortInfo = `Sort: col ${col} DESC (${ms}ms)`;
    updateStatus();
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
    wasmModule.demo_materialize_visible_rows(grid.id, 48);
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
  chkGpu.checked = false;
  chkGpu.addEventListener("change", () => {
    activeRendererMode = chkGpu.checked ? 2 : 1;
    applyActiveRenderSettings();
    grid.invalidate();
  });

  chkScrollBlit.addEventListener("change", () => {
    scrollBlitEnabled = chkScrollBlit.checked;
    applyScrollBlitToKnownGrids();
    applyActiveRenderSettings();
    grid.invalidate();
  });

  chkEdit.addEventListener("change", () => {
    editEnabled = chkEdit.checked;
    applyEditableToKnownDemoGrids();
    if (currentDemo !== "doom") {
      updateStatus(editEnabled ? "Edit enabled" : "Edit disabled");
    }
  });

  // Animation toggle.
  chkAnim.addEventListener("change", () => {
    applyActiveRenderSettings();
    grid.invalidate();
  });

  // Hover highlight toggle.
  chkHover.addEventListener("change", () => {
    applyHoverToggleToKnownGrids();
  });

  btnLayers.addEventListener("click", () => {
    setLayerPanelOpen(layerPanel.hidden);
  });
  btnLayersAll.addEventListener("click", () => {
    commitLayerMask(LAYER_MASK_ALL);
  });
  btnLayersNone.addEventListener("click", () => {
    commitLayerMask(0);
  });

  // Debug overlay toggle.
  chkDebug.addEventListener("change", () => {
    applyActiveRenderSettings();
    grid.invalidate();
  });

  // Text layout cache cap.
  selTextCache.addEventListener("change", () => {
    const cap = selectedTextLayoutCacheCap();
    grid.textLayoutCacheCap = cap;
    if (canvas2DRenderer) {
      canvas2DRenderer.setCacheSize(cap);
    }
    grid.invalidate();
  });

  // Initial options can be configured from:
  // `make web WEB_SCALE=<value> WEB_HOVER=<true|false>`
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
