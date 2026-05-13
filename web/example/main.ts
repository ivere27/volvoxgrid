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
  VolvoxGrid,
  type VolvoxGridContextMenuRequest,
  type VolvoxGridDropdown,
  type VolvoxGridValidationError,
} from "../js/src/volvoxgrid.js";
import { setupDefaultInput } from "../js/src/default-input.js";
import { createCanvas2DTextRenderer } from "../js/src/canvas2d-text-renderer.js";
import {
  AggregateType,
  Align,
  BarcodeCaptionOptionsFields,
  BarcodeCaptionPosition,
  BarcodeCheckDigitMode,
  BarcodeDataFields,
  BarcodeEncodingOptionsFields,
  BarcodeQrErrorCorrection,
  BarcodeRenderOptionsFields,
  BarcodeSymbology,
  BarcodeTextEncoding,
  BorderFields,
  BorderStyle,
  BordersFields,
  CellHitArea,
  CellInteraction,
  CellSpanMode,
  CellStyleFields,
  CellUpdateFields,
  CellValueFields,
  ColIndicatorCellMode,
  ColIndicatorConfigFields,
  ColumnDefFields,
  ColumnDataType,
  CornerIndicatorConfigFields,
  CornerIndicatorSlotKind,
  CornerIndicatorSlotFields,
  DefineColumnsRequestFields,
  DefineRowsRequestFields,
  EditActivationFields,
  EditConfigFields,
  EditTrigger,
  EditorKind,
  EditorOwner,
  EditorPresentation,
  EditorSpecFields,
  EditorUpdateReason,
  FillHandlePosition,
  FocusBorderStyle,
  FontFields,
  FreezePolicyFields,
  GridConfigFields,
  GridLinesFields,
  GridLineStyle,
  GroupTotalPosition,
  HeaderFeaturesFields,
  HeaderResizeHandleFields,
  HeaderSeparatorFields,
  HeaderStyleFields,
  HighlightStyleFields,
  HoverConfigFields,
  ImageAlignment,
  IndicatorAppearance,
  IndicatorsConfigFields,
  InteractionConfigFields,
  LayoutConfigFields,
  ListEditorParamsFields,
  ListItemFields,
  LoadDataStatus,
  NumberEditorParamsFields,
  OutlineConfigFields,
  PaddingFields,
  PresentMode,
  RegionStyleFields,
  RenderLayerBit,
  RendererMode,
  ResizePolicyFields,
  RichTextFields,
  RowDefFields,
  RowIndicatorConfigFields,
  RowIndicatorSlotKind,
  RowIndicatorSlotFields,
  ScrollConfigFields,
  ScrollBarsMode,
  SelectionConfigFields,
  SelectionMode,
  SelectionVisibility,
  SpanConfigFields,
  SpanCompareMode,
  StyleConfigFields,
  TabBehavior,
  TextBaseline,
  TextFormatRunFields,
  TreeIndicatorStyle,
  TextRunStyleFields,
  UpdateCellsRequestFields,
} from "../js/src/generated/volvoxgrid_ffi.js";
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

type DemoMode = "stress" | "sales" | "hierarchy" | "barcodes" | "doom";
type StandardDemoMode = Exclude<DemoMode, "doom">;
type DoomDirectionCode = "ArrowUp" | "ArrowDown" | "ArrowLeft" | "ArrowRight";
type DoomTouchActionCode = "ControlLeft" | "Space" | "Enter";

const STRESS_ROWS = 1_000_000;
const STRESS_COLS = 12;
const SALES_COLS = 10;
const HIERARCHY_COLS = 8;
const BARCODE_COLS = 6;
const SALES_STATUS_ITEMS = "Active|Pending|Shipped|Returned|Cancelled";
const HIERARCHY_NAME_COL = 0;
const HIERARCHY_TYPE_COL = 1;
const HIERARCHY_DETAILS_COL = 5;
const HIERARCHY_ACTION_COL = 6;
const HIERARCHY_ICON_COL = 7;
const HIERARCHY_FOLDER_ICON = "\uE2C7";
enum NodeChildrenState {
  NODE_LEAF = 1,
  NODE_CHILDREN_LOADED = 4,
}
const NodeCellUpdateFields = {
  node_id: 1,
  col: 2,
  value: 3,
  style: 4,
  rich_text: 9,
} as const;
const TreeNodeFields = {
  node_id: 1,
  parent_id: 2,
  cells: 4,
  children_state: 5,
} as const;
const LoadTreeRequestFields = {
  grid_id: 1,
  nodes: 2,
  replace: 3,
} as const;
const CELL_INTERACTION_TEXT_LINK = CellInteraction.CELL_INTERACTION_TEXT_LINK;
const CELL_HIT_AREA_TEXT = CellHitArea.HIT_TEXT;
const FONT_FETCH_TIMEOUT_MS = 5000;
const DEMO_DEFAULT_FONT_FAMILY = "Roboto";
const MATERIAL_ICONS_FONT_URL =
  "https://cdn.jsdelivr.net/npm/material-design-icons@3.0.1/iconfont/MaterialIcons-Regular.ttf";
const MATERIAL_ICON_CHEVRON_RIGHT = "\uE5CC";
const MATERIAL_ICON_EXPAND_MORE = "\uE5CF";
const ICON_SLOT_TREE_EXPANDED = 4;
const ICON_SLOT_TREE_COLLAPSED = 5;
const PB_TEXT_ENCODER = new TextEncoder();
const PB_TEXT_DECODER = new TextDecoder();
const HOVER_NONE = 0;
const HOVER_ROW = 1;
const HOVER_COLUMN = 2;
const HOVER_CELL = 4;
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

const SALES_COLUMN_SETUP = [
  { caption: "Q", key: "Q", align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, span: true },
  { caption: "Region", key: "Region", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: true },
  { caption: "Category", key: "Category", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Product", key: "Product", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Sales", key: "Sales", align: Align.ALIGN_RIGHT_CENTER, dataType: ColumnDataType.COLUMN_DATA_CURRENCY, format: "$#,##0", dropdownItems: undefined, numberEditor: { min: 0 }, span: false },
  { caption: "Cost", key: "Cost", align: Align.ALIGN_RIGHT_CENTER, dataType: ColumnDataType.COLUMN_DATA_CURRENCY, format: "$#,##0", dropdownItems: undefined, numberEditor: { min: 0 }, span: false },
  { caption: "Margin%", key: "Margin", align: Align.ALIGN_CENTER_CENTER, dataType: ColumnDataType.COLUMN_DATA_NUMBER, format: undefined, dropdownItems: undefined, numberEditor: { min: 0, max: 100 }, span: false },
  { caption: "Flag", key: "Flag", align: Align.ALIGN_CENTER_CENTER, dataType: ColumnDataType.COLUMN_DATA_BOOLEAN, format: undefined, dropdownItems: undefined, span: false },
  { caption: "Status", key: "Status", align: undefined, dataType: undefined, format: undefined, dropdownItems: SALES_STATUS_ITEMS, span: false },
  { caption: "Notes", key: "Notes", align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, span: false },
] as const;
const HIERARCHY_COLUMN_SETUP = [
  { caption: "Name", key: "Name", width: 260, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined, hidden: true },
  { caption: "Type", key: "Type", width: 80, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Size", key: "Size", width: 80, align: Align.ALIGN_RIGHT_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Modified", key: "Modified", width: 120, align: undefined, dataType: ColumnDataType.COLUMN_DATA_DATE, format: "short date", dropdownItems: undefined, interaction: undefined },
  { caption: "Permissions", key: "Permissions", width: 100, align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Details", key: "Details", width: 180, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Action", key: "Action", width: 92, align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: CellInteraction.CELL_INTERACTION_TEXT_LINK },
  { caption: "Icon", key: "Icon", width: 24, align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined, hidden: true },
] as const;
const BARCODE_COLUMN_SETUP = [
  { caption: "Symbology", key: "Symbology", align: Align.ALIGN_CENTER_CENTER },
  { caption: "Payload", key: "Value" },
  { caption: "TextEncoding", key: "TextEncoding", align: Align.ALIGN_CENTER_CENTER },
  { caption: "Settings", key: "Label" },
  { caption: "Barcode", key: "Barcode", align: Align.ALIGN_CENTER_CENTER },
  { caption: "Notes", key: "Notes" },
] as const;
type DemoColumnSetup = {
  caption: string;
  key: string;
  width?: number;
  align?: number;
  dataType?: number;
  format?: string;
  dropdownItems?: string;
  numberEditor?: {
    min?: number;
    max?: number;
    nullable?: boolean;
  };
  interaction?: number;
  hidden?: boolean;
  span?: boolean;
};
type DemoFontAsset = {
  label: string;
  url: string;
  family?: string;
  aliases?: string[];
  weight?: string;
  style?: string;
};
type HierarchyRichTextRunStyle = {
  foreground?: string | number;
  color?: string | number;
  fg?: string | number;
  family?: string;
  families?: string[];
  size?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  strike?: boolean;
  stretch?: number;
  baseline?: string | number;
  linkUrl?: string;
  link_url?: string;
  href?: string;
  font?: HierarchyRichTextRunStyle;
};
type HierarchyRichTextRun = HierarchyRichTextRunStyle & {
  start?: number;
  startIndex?: number;
  start_index?: number;
  style?: HierarchyRichTextRunStyle;
};
type HierarchyRichTextCell = {
  text?: string;
  value?: string;
  richText?: HierarchyRichTextRun[] | { runs?: HierarchyRichTextRun[] };
  rich_text?: HierarchyRichTextRun[] | { runs?: HierarchyRichTextRun[] };
};
type HierarchyDemoRow = {
  Id: string;
  ParentId: string | null;
  Name: string;
  Type: string;
  Size: string;
  Modified: string;
  Permissions: string;
  Details?: string | HierarchyRichTextCell | null;
  Action: string;
};
type BarcodeJsonRow = {
  Symbology: string;
  Value: string;
  TextEncoding?: string;
  QrEcc?: string;
  Label: string;
  Notes: string;
};
type DemoRowSetup = {
  height?: number;
  outlineLevel?: number;
  isSubtotal?: boolean;
};
type DemoFontSpec = {
  family?: string;
  families?: string[];
  size?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  stretch?: number;
};
type DemoCellStyleSpec = {
  background?: number;
  foreground?: number;
  align?: number;
  font?: DemoFontSpec;
  padding?: {
    left?: number;
    top?: number;
    right?: number;
    bottom?: number;
  };
  borderAll?: {
    style: number;
    color: number;
  };
};
type BarcodeDemoPlan = {
  symbology: number;
  checkDigit: number;
  textEncoding: number;
  qrEcc: number;
  foreground: number;
  background: number;
  alignment: number;
  moduleSize: number;
  quietZone: number;
  barHeight: number;
  narrowBarWidth: number;
  captionPosition: number;
  captionColor: number;
  rowHeight: number;
  optionsText: string;
};
type WasmModule = typeof import("./wasm/volvoxgrid_wasm.js");
type HierarchyTreeWasmModule = WasmModule & {
  volvox_tree_load_tree_pb?: (data: Uint8Array) => Uint8Array;
};

function hierarchyRowDepths(rows: ReadonlyArray<HierarchyDemoRow>): number[] {
  const rowsById = new Map(rows.map((row) => [row.Id, row]));
  const depthCache = new Map<string, number>();
  const depthFor = (row: HierarchyDemoRow, visiting: Set<string>): number => {
    const cached = depthCache.get(row.Id);
    if (cached !== undefined) {
      return cached;
    }
    if (visiting.has(row.Id)) {
      throw new Error(`hierarchy demo data contains a parent cycle at ${row.Id}`);
    }
    visiting.add(row.Id);
    const parentId = row.ParentId?.trim() ?? "";
    let depth = 0;
    if (parentId !== "") {
      const parent = rowsById.get(parentId);
      if (!parent) {
        throw new Error(`hierarchy demo data references missing parent ${parentId}`);
      }
      depth = depthFor(parent, visiting) + 1;
    }
    visiting.delete(row.Id);
    depthCache.set(row.Id, depth);
    return depth;
  };
  return rows.map((row) => depthFor(row, new Set<string>()));
}

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

  const source = fontData.buffer.slice(
    fontData.byteOffset,
    fontData.byteOffset + fontData.byteLength,
  );
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

function loadDemoFontsInBackground(
  wasmModule: WasmModule,
): Promise<boolean> {
  const fonts = demoFontAssetsForLocales(browserLocaleHints());

  return Promise.all(
    fonts.map(async (font) => {
      const fontData = await fetchFontWithTimeout(font.url);
      if (fontData) {
        wasmModule.load_font(fontData);
        await loadBrowserFontFaces(font, fontData);
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

function pbEncodeDoubleField(field: number, value: number): number[] {
  const buf = new ArrayBuffer(8);
  new DataView(buf).setFloat64(0, value, true);
  return [...pbEncodeTag(field, 1), ...Array.from(new Uint8Array(buf))];
}

function pbEncodeBorder(style: number, color: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(BorderFields.style, style));
  out.push(...pbEncodeUint32Field(BorderFields.color, color));
  return new Uint8Array(out);
}

function pbEncodeBordersAll(style: number, color: number): Uint8Array {
  return new Uint8Array(pbEncodeMessageField(BordersFields.all, pbEncodeBorder(style, color)));
}

function pbEncodeFontPayload(font: DemoFontSpec): Uint8Array {
  const out: number[] = [];
  if (font.family != null && font.family !== "") {
    out.push(...pbEncodeStringField(FontFields.family, font.family));
  }
  if (font.families != null) {
    for (const family of font.families) {
      if (family !== "") {
        out.push(...pbEncodeStringField(FontFields.families, family));
      }
    }
  }
  if (font.size != null) {
    out.push(...pbEncodeFloatField(FontFields.size, font.size));
  }
  if (font.bold != null) {
    out.push(...pbEncodeTag(FontFields.bold, 0), ...pbEncodeBool(font.bold));
  }
  if (font.italic != null) {
    out.push(...pbEncodeTag(FontFields.italic, 0), ...pbEncodeBool(font.italic));
  }
  if (font.underline != null) {
    out.push(...pbEncodeTag(FontFields.underline, 0), ...pbEncodeBool(font.underline));
  }
  if (font.strikethrough != null) {
    out.push(...pbEncodeTag(FontFields.strikethrough, 0), ...pbEncodeBool(font.strikethrough));
  }
  if (font.stretch != null) {
    out.push(...pbEncodeFloatField(FontFields.stretch, font.stretch));
  }
  return new Uint8Array(out);
}

function pbEncodePaddingPayload(padding: DemoCellStyleSpec["padding"]): Uint8Array {
  const out: number[] = [];
  if (padding?.left != null) {
    out.push(...pbEncodeInt32Field(PaddingFields.left, padding.left));
  }
  if (padding?.top != null) {
    out.push(...pbEncodeInt32Field(PaddingFields.top, padding.top));
  }
  if (padding?.right != null) {
    out.push(...pbEncodeInt32Field(PaddingFields.right, padding.right));
  }
  if (padding?.bottom != null) {
    out.push(...pbEncodeInt32Field(PaddingFields.bottom, padding.bottom));
  }
  return new Uint8Array(out);
}

function pbEncodeCellStylePayload(style: DemoCellStyleSpec): Uint8Array {
  const out: number[] = [];
  if (style.background != null) {
    out.push(...pbEncodeUint32Field(CellStyleFields.background, style.background));
  }
  if (style.foreground != null) {
    out.push(...pbEncodeUint32Field(CellStyleFields.foreground, style.foreground));
  }
  if (style.align != null) {
    out.push(...pbEncodeInt32Field(CellStyleFields.align, style.align));
  }
  if (style.font != null) {
    const font = pbEncodeFontPayload(style.font);
    if (font.length > 0) {
      out.push(...pbEncodeMessageField(CellStyleFields.font, font));
    }
  }
  if (style.padding != null) {
    const padding = pbEncodePaddingPayload(style.padding);
    if (padding.length > 0) {
      out.push(...pbEncodeMessageField(CellStyleFields.padding, padding));
    }
  }
  if (style.borderAll != null) {
    out.push(...pbEncodeMessageField(CellStyleFields.borders, pbEncodeBordersAll(style.borderAll.style, style.borderAll.color)));
  }
  return new Uint8Array(out);
}

function pbEncodeCellValueText(text: string): Uint8Array {
  return new Uint8Array(pbEncodeStringField(CellValueFields.text, text));
}

function parseArgb(value: string | number | undefined): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value >>> 0;
  }
  if (typeof value !== "string") {
    return undefined;
  }
  const raw = value.trim();
  if (raw === "") {
    return undefined;
  }
  const hex = raw.replace(/^#|^0x/i, "");
  if (/^[0-9a-fA-F]{6}$/.test(hex)) {
    return (0xFF000000 | Number.parseInt(hex, 16)) >>> 0;
  }
  if (/^[0-9a-fA-F]{8}$/.test(hex)) {
    return Number.parseInt(hex, 16) >>> 0;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed >>> 0 : undefined;
}

function parseTextBaseline(value: string | number | undefined): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value !== "string") {
    return undefined;
  }
  switch (value.trim().toLowerCase()) {
    case "normal":
      return TextBaseline.TEXT_BASELINE_NORMAL;
    case "superscript":
    case "super":
      return TextBaseline.TEXT_BASELINE_SUPERSCRIPT;
    case "subscript":
    case "sub":
      return TextBaseline.TEXT_BASELINE_SUBSCRIPT;
    default:
      return undefined;
  }
}

function pbEncodeRichTextRunStylePayload(run: HierarchyRichTextRun): Uint8Array {
  const style = run.style ?? run;
  const out: number[] = [];
  const foreground = parseArgb(style.foreground ?? style.color ?? style.fg);
  if (foreground != null) {
    out.push(...pbEncodeUint32Field(TextRunStyleFields.foreground, foreground));
  }

  const fontSource = style.font ?? style;
  const font = pbEncodeFontPayload({
    family: fontSource.family,
    families: fontSource.families,
    size: fontSource.size,
    bold: fontSource.bold,
    italic: fontSource.italic,
    underline: fontSource.underline,
    strikethrough: fontSource.strikethrough ?? fontSource.strike,
    stretch: fontSource.stretch,
  });
  if (font.length > 0) {
    out.push(...pbEncodeMessageField(TextRunStyleFields.font, font));
  }

  const baseline = parseTextBaseline(style.baseline);
  if (baseline != null) {
    out.push(...pbEncodeInt32Field(TextRunStyleFields.baseline, baseline));
  }
  const linkUrl = style.linkUrl ?? style.link_url ?? style.href;
  if (linkUrl != null && linkUrl !== "") {
    out.push(...pbEncodeStringField(TextRunStyleFields.link_url, linkUrl));
  }
  return new Uint8Array(out);
}

function pbEncodeRichTextRun(run: HierarchyRichTextRun): Uint8Array {
  const start = run.start ?? run.startIndex ?? run.start_index;
  if (start == null || !Number.isFinite(start) || start < 0) {
    return new Uint8Array();
  }
  const out: number[] = [];
  out.push(...pbEncodeUint32Field(TextFormatRunFields.start_index, Math.trunc(start)));
  const style = pbEncodeRichTextRunStylePayload(run);
  if (style.length > 0) {
    out.push(...pbEncodeMessageField(TextFormatRunFields.style, style));
  }
  return new Uint8Array(out);
}

function hierarchyRichTextRuns(
  richText: HierarchyRichTextCell["richText"] | HierarchyRichTextCell["rich_text"],
): HierarchyRichTextRun[] {
  if (Array.isArray(richText)) {
    return richText;
  }
  return richText?.runs ?? [];
}

function hierarchyDetailsCell(details: HierarchyDemoRow["Details"]): {
  text: string;
  richText?: Uint8Array;
} {
  if (typeof details === "string") {
    return { text: details };
  }
  if (details == null) {
    return { text: "" };
  }

  const text = details.text ?? details.value ?? "";
  const runs = hierarchyRichTextRuns(details.richText ?? details.rich_text);
  const encodedRuns = runs.map(pbEncodeRichTextRun).filter((run) => run.length > 0);
  if (text === "" || encodedRuns.length === 0) {
    return { text };
  }

  const out: number[] = [];
  for (const run of encodedRuns) {
    out.push(...pbEncodeMessageField(RichTextFields.runs, run));
  }
  return { text, richText: new Uint8Array(out) };
}

function pbEncodeBarcodeEncodingOptions(plan: BarcodeDemoPlan): Uint8Array {
  const out: number[] = [];
  if (plan.checkDigit !== BarcodeCheckDigitMode.CHECK_DIGIT_DEFAULT) {
    out.push(...pbEncodeInt32Field(BarcodeEncodingOptionsFields.check_digit, plan.checkDigit));
  }
  if (plan.textEncoding !== BarcodeTextEncoding.BARCODE_TEXT_AUTO) {
    out.push(...pbEncodeInt32Field(BarcodeEncodingOptionsFields.text_encoding, plan.textEncoding));
  }
  if (plan.qrEcc !== BarcodeQrErrorCorrection.QR_ECC_DEFAULT) {
    out.push(...pbEncodeInt32Field(BarcodeEncodingOptionsFields.qr_ecc, plan.qrEcc));
  }
  return new Uint8Array(out);
}

function pbEncodeBarcodeRenderOptions(plan: BarcodeDemoPlan): Uint8Array {
  const out: number[] = [];
  if (plan.foreground !== 0) {
    out.push(...pbEncodeUint32Field(BarcodeRenderOptionsFields.foreground, plan.foreground));
  }
  if (plan.background !== 0) {
    out.push(...pbEncodeUint32Field(BarcodeRenderOptionsFields.background, plan.background));
  }
  if (plan.alignment !== ImageAlignment.IMG_ALIGN_STRETCH) {
    out.push(...pbEncodeInt32Field(BarcodeRenderOptionsFields.alignment, plan.alignment));
  }
  if (plan.moduleSize !== 0) {
    out.push(...pbEncodeUint32Field(BarcodeRenderOptionsFields.module_size, plan.moduleSize));
  }
  if (plan.quietZone !== 0) {
    out.push(...pbEncodeUint32Field(BarcodeRenderOptionsFields.quiet_zone, plan.quietZone));
  }
  if (plan.barHeight !== 0) {
    out.push(...pbEncodeUint32Field(BarcodeRenderOptionsFields.bar_height, plan.barHeight));
  }
  if (plan.narrowBarWidth !== 0) {
    out.push(...pbEncodeUint32Field(BarcodeRenderOptionsFields.narrow_bar_width, plan.narrowBarWidth));
  }
  out.push(...pbEncodeTag(BarcodeRenderOptionsFields.show_size_warning, 0), ...pbEncodeBool(true));
  out.push(...pbEncodeTag(BarcodeRenderOptionsFields.use_full_rect, 0), ...pbEncodeBool(true));
  return new Uint8Array(out);
}

function pbEncodeBarcodeCaptionOptions(record: BarcodeJsonRow, plan: BarcodeDemoPlan): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(BarcodeCaptionOptionsFields.position, plan.captionPosition));
  out.push(...pbEncodeStringField(BarcodeCaptionOptionsFields.text, record.Label));
  out.push(...pbEncodeUint32Field(BarcodeCaptionOptionsFields.color, plan.captionColor));
  return new Uint8Array(out);
}

function pbEncodeBarcodeData(record: BarcodeJsonRow, plan: BarcodeDemoPlan): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(BarcodeDataFields.symbology, plan.symbology));
  const encoding = pbEncodeBarcodeEncodingOptions(plan);
  if (encoding.length > 0) {
    out.push(...pbEncodeMessageField(BarcodeDataFields.encoding, encoding));
  }
  const render = pbEncodeBarcodeRenderOptions(plan);
  if (render.length > 0) {
    out.push(...pbEncodeMessageField(BarcodeDataFields.render, render));
  }
  const caption = pbEncodeBarcodeCaptionOptions(record, plan);
  if (caption.length > 0) {
    out.push(...pbEncodeMessageField(BarcodeDataFields.caption, caption));
  }
  return new Uint8Array(out);
}

function pbEncodeCellUpdate(options: {
  row: number;
  col: number;
  valueText?: string;
  style?: DemoCellStyleSpec;
  barcode?: Uint8Array;
}): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(CellUpdateFields.row, options.row));
  out.push(...pbEncodeInt32Field(CellUpdateFields.col, options.col));
  if (options.valueText != null) {
    out.push(...pbEncodeMessageField(CellUpdateFields.value, pbEncodeCellValueText(options.valueText)));
  }
  if (options.style != null) {
    const style = pbEncodeCellStylePayload(options.style);
    if (style.length > 0) {
      out.push(...pbEncodeMessageField(CellUpdateFields.style, style));
    }
  }
  if (options.barcode != null) {
    out.push(...pbEncodeMessageField(CellUpdateFields.barcode, options.barcode));
  }
  return new Uint8Array(out);
}

function pbEncodeUpdateCellsRequest(
  gridId: number,
  cells: readonly Uint8Array[],
  atomic: boolean,
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(UpdateCellsRequestFields.grid_id, 0), ...pbEncodeVarint(BigInt(Math.trunc(gridId))));
  for (const cell of cells) {
    out.push(...pbEncodeMessageField(UpdateCellsRequestFields.cells, cell));
  }
  out.push(...pbEncodeTag(UpdateCellsRequestFields.atomic, 0), ...pbEncodeBool(atomic));
  return new Uint8Array(out);
}

function pbEncodeTreeNodeCell(options: {
  nodeId: string;
  col: number;
  text: string;
  style?: DemoCellStyleSpec;
  richText?: Uint8Array;
}): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeStringField(NodeCellUpdateFields.node_id, options.nodeId));
  out.push(...pbEncodeInt32Field(NodeCellUpdateFields.col, options.col));
  out.push(...pbEncodeMessageField(NodeCellUpdateFields.value, pbEncodeCellValueText(options.text)));
  if (options.style != null) {
    const style = pbEncodeCellStylePayload(options.style);
    if (style.length > 0) {
      out.push(...pbEncodeMessageField(NodeCellUpdateFields.style, style));
    }
  }
  if (options.richText != null && options.richText.length > 0) {
    out.push(...pbEncodeMessageField(NodeCellUpdateFields.rich_text, options.richText));
  }
  return new Uint8Array(out);
}

function pbEncodeHierarchyTreeNode(
  row: HierarchyDemoRow,
  hasChildren: boolean,
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeStringField(TreeNodeFields.node_id, row.Id));
  if (row.ParentId != null && row.ParentId !== "") {
    out.push(...pbEncodeStringField(TreeNodeFields.parent_id, row.ParentId));
  }
  const details = hierarchyDetailsCell(row.Details);
  const cells = [
    pbEncodeTreeNodeCell({ nodeId: row.Id, col: HIERARCHY_NAME_COL, text: row.Name }),
    pbEncodeTreeNodeCell({
      nodeId: row.Id,
      col: HIERARCHY_TYPE_COL,
      text: row.Type,
      style: row.Type === "Folder" ? { foreground: 0xFF92400E } : undefined,
    }),
    pbEncodeTreeNodeCell({ nodeId: row.Id, col: 2, text: row.Size }),
    pbEncodeTreeNodeCell({ nodeId: row.Id, col: 3, text: row.Modified }),
    pbEncodeTreeNodeCell({ nodeId: row.Id, col: 4, text: row.Permissions }),
    pbEncodeTreeNodeCell({
      nodeId: row.Id,
      col: HIERARCHY_DETAILS_COL,
      text: details.text,
      richText: details.richText,
    }),
    pbEncodeTreeNodeCell({
      nodeId: row.Id,
      col: HIERARCHY_ACTION_COL,
      text: row.Action,
      style: { foreground: 0xFF2563EB },
    }),
    pbEncodeTreeNodeCell({
      nodeId: row.Id,
      col: HIERARCHY_ICON_COL,
      text: row.Type === "Folder" ? HIERARCHY_FOLDER_ICON : "",
    }),
  ];
  cells.forEach((cell) => {
    out.push(...pbEncodeMessageField(TreeNodeFields.cells, cell));
  });
  out.push(...pbEncodeInt32Field(
    TreeNodeFields.children_state,
    hasChildren ? NodeChildrenState.NODE_CHILDREN_LOADED : NodeChildrenState.NODE_LEAF,
  ));
  return new Uint8Array(out);
}

function pbEncodeHierarchyLoadTreeRequest(
  gridId: number,
  rows: ReadonlyArray<HierarchyDemoRow>,
): Uint8Array {
  const parentIds = new Set(rows.map((row) => row.ParentId).filter((id): id is string => !!id));
  const out: number[] = [];
  out.push(...pbEncodeTag(LoadTreeRequestFields.grid_id, 0), ...pbEncodeVarint(BigInt(Math.trunc(gridId))));
  rows.forEach((row) => {
    out.push(...pbEncodeMessageField(LoadTreeRequestFields.nodes, pbEncodeHierarchyTreeNode(row, parentIds.has(row.Id))));
  });
  out.push(...pbEncodeTag(LoadTreeRequestFields.replace, 0), ...pbEncodeBool(true));
  return new Uint8Array(out);
}

function pbEncodeGridLinesPayload(color: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(GridLinesFields.style, GridLineStyle.GRIDLINE_SOLID));
  out.push(...pbEncodeUint32Field(GridLinesFields.color, color));
  return new Uint8Array(out);
}

function pbEncodeRegionStylePayload(background: number, foreground: number, gridColor: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeUint32Field(RegionStyleFields.background, background));
  out.push(...pbEncodeUint32Field(RegionStyleFields.foreground, foreground));
  out.push(...pbEncodeMessageField(RegionStyleFields.grid_lines, pbEncodeGridLinesPayload(gridColor)));
  return new Uint8Array(out);
}

function pbEncodeHeaderStylePayload(color: number): Uint8Array {
  const separator: number[] = [];
  separator.push(...pbEncodeTag(HeaderSeparatorFields.enabled, 0), ...pbEncodeBool(true));
  separator.push(...pbEncodeUint32Field(HeaderSeparatorFields.color, color));
  separator.push(...pbEncodeInt32Field(HeaderSeparatorFields.width, 1));

  const resizeHandle: number[] = [];
  resizeHandle.push(...pbEncodeTag(HeaderResizeHandleFields.enabled, 0), ...pbEncodeBool(true));
  resizeHandle.push(...pbEncodeUint32Field(HeaderResizeHandleFields.color, color));
  resizeHandle.push(...pbEncodeInt32Field(HeaderResizeHandleFields.width, 1));
  resizeHandle.push(...pbEncodeInt32Field(HeaderResizeHandleFields.hit_width, 6));

  const out: number[] = [];
  out.push(...pbEncodeMessageField(HeaderStyleFields.separator, new Uint8Array(separator)));
  out.push(...pbEncodeMessageField(HeaderStyleFields.resize_handle, new Uint8Array(resizeHandle)));
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
    out.push(...pbEncodeUint32Field(HighlightStyleFields.background, options.background));
  }
  if (options.foreground != null) {
    out.push(...pbEncodeUint32Field(HighlightStyleFields.foreground, options.foreground));
  }
  if (options.borderStyle != null && options.borderColor != null) {
    out.push(...pbEncodeMessageField(HighlightStyleFields.borders, pbEncodeBordersAll(options.borderStyle, options.borderColor)));
  }
  if (options.fillHandle != null) {
    out.push(...pbEncodeInt32Field(HighlightStyleFields.fill_handle, options.fillHandle));
  }
  if (options.fillHandleColor != null) {
    out.push(...pbEncodeUint32Field(HighlightStyleFields.fill_handle_color, options.fillHandleColor));
  }
  return new Uint8Array(out);
}

function pbEncodeColumnDef(
  index: number,
  setup: DemoColumnSetup,
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(ColumnDefFields.index, index));
  if (setup.width != null) {
    out.push(...pbEncodeInt32Field(ColumnDefFields.width, setup.width));
  }
  out.push(...pbEncodeStringField(ColumnDefFields.caption, setup.caption));
  if (setup.align != null) {
    out.push(...pbEncodeInt32Field(ColumnDefFields.align, setup.align));
  }
  if (setup.dataType != null) {
    out.push(...pbEncodeInt32Field(ColumnDefFields.data_type, setup.dataType));
  }
  if (setup.format != null) {
    out.push(...pbEncodeStringField(ColumnDefFields.format, setup.format));
  }
  out.push(...pbEncodeStringField(ColumnDefFields.key, setup.key));
  if (setup.dropdownItems != null) {
    out.push(...pbEncodeMessageField(ColumnDefFields.editor, pbEncodeDropdownEditorFromLabels(setup.dropdownItems)));
  } else if (setup.numberEditor != null) {
    out.push(...pbEncodeMessageField(ColumnDefFields.editor, pbEncodeNumberEditor(setup.numberEditor)));
  }
  if (setup.hidden != null) {
    out.push(...pbEncodeTag(ColumnDefFields.hidden, 0), ...pbEncodeBool(setup.hidden));
  }
  if (setup.span != null) {
    out.push(...pbEncodeTag(ColumnDefFields.span, 0), ...pbEncodeBool(setup.span));
  }
  if (setup.interaction != null) {
    out.push(...pbEncodeInt32Field(ColumnDefFields.interaction, setup.interaction));
  }
  return new Uint8Array(out);
}

function pbEncodeDropdownEditorFromLabels(items: string): Uint8Array {
  const list: number[] = [];
  let source = items;
  const allowCustomValue = source.startsWith("|");
  if (source.startsWith("|")) {
    list.push(...pbEncodeTag(ListEditorParamsFields.allow_custom_value, 0), ...pbEncodeBool(true));
    source = source.slice(1);
  }
  for (const label of source.split("|")) {
    if (!label) continue;
    list.push(...pbEncodeMessageField(
      ListEditorParamsFields.static_items,
      new Uint8Array(pbEncodeStringField(ListItemFields.label, label)),
    ));
  }
  const editor: number[] = [];
  editor.push(...pbEncodeInt32Field(
    EditorSpecFields.kind,
    allowCustomValue ? EditorKind.EDITOR_COMBO : EditorKind.EDITOR_SELECT,
  ));
  editor.push(...pbEncodeInt32Field(EditorSpecFields.owner, EditorOwner.EDITOR_OWNER_ENGINE));
  editor.push(...pbEncodeInt32Field(EditorSpecFields.presentation, EditorPresentation.EDITOR_CANVAS));
  editor.push(...pbEncodeMessageField(EditorSpecFields.list, new Uint8Array(list)));
  return new Uint8Array(editor);
}

function pbEncodeNumberEditor(options: { min?: number; max?: number; nullable?: boolean }): Uint8Array {
  const number: number[] = [];
  if (options.min != null) {
    number.push(...pbEncodeDoubleField(NumberEditorParamsFields.min, options.min));
  }
  if (options.max != null) {
    number.push(...pbEncodeDoubleField(NumberEditorParamsFields.max, options.max));
  }
  if (options.nullable === true) {
    number.push(...pbEncodeTag(NumberEditorParamsFields.nullable, 0), ...pbEncodeBool(true));
  }

  const editor: number[] = [];
  editor.push(...pbEncodeInt32Field(EditorSpecFields.kind, EditorKind.EDITOR_NUMBER));
  editor.push(...pbEncodeInt32Field(EditorSpecFields.owner, EditorOwner.EDITOR_OWNER_HOST_NATIVE));
  editor.push(...pbEncodeInt32Field(EditorSpecFields.presentation, EditorPresentation.EDITOR_INLINE));
  editor.push(...pbEncodeMessageField(EditorSpecFields.number, new Uint8Array(number)));
  return new Uint8Array(editor);
}

function defaultHostTextEditor(): Uint8Array {
  const editor: number[] = [];
  editor.push(...pbEncodeInt32Field(EditorSpecFields.kind, EditorKind.EDITOR_TEXT));
  editor.push(...pbEncodeInt32Field(EditorSpecFields.owner, EditorOwner.EDITOR_OWNER_HOST_NATIVE));
  editor.push(...pbEncodeInt32Field(EditorSpecFields.presentation, EditorPresentation.EDITOR_INLINE));
  return new Uint8Array(editor);
}

function dropdownFromLabels(items: string): VolvoxGridDropdown {
  let source = items;
  const dropdown: VolvoxGridDropdown = {
    items: [],
    allowCustomValue: source.startsWith("|"),
  };
  if (dropdown.allowCustomValue) {
    source = source.slice(1);
  }
  for (const label of source.split("|")) {
    if (!label) continue;
    dropdown.items.push({ label });
  }
  return dropdown;
}

function pbEncodeDefineColumnsRequest(gridId: number, columns: readonly DemoColumnSetup[]): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(DefineColumnsRequestFields.grid_id, 0), ...pbEncodeVarint(BigInt(gridId)));
  columns.forEach((column, index) => {
    out.push(...pbEncodeMessageField(DefineColumnsRequestFields.columns, pbEncodeColumnDef(index, column)));
  });
  return new Uint8Array(out);
}

function pbEncodeRowDef(index: number, row: DemoRowSetup): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeInt32Field(RowDefFields.index, index));
  if (row.height != null) {
    out.push(...pbEncodeInt32Field(RowDefFields.height, row.height));
  }
  if (row.isSubtotal != null) {
    out.push(...pbEncodeTag(RowDefFields.is_subtotal, 0), ...pbEncodeBool(row.isSubtotal));
  }
  if (row.outlineLevel != null) {
    out.push(...pbEncodeInt32Field(RowDefFields.outline_level, row.outlineLevel));
  }
  return new Uint8Array(out);
}

function pbEncodeDefineRowsRequest(
  gridId: number,
  rows: ReadonlyArray<DemoRowSetup>,
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(DefineRowsRequestFields.grid_id, 0), ...pbEncodeVarint(BigInt(gridId)));
  rows.forEach((row, index) => {
    out.push(...pbEncodeMessageField(DefineRowsRequestFields.rows, pbEncodeRowDef(index, row)));
  });
  return new Uint8Array(out);
}

function hierarchyOutlineWidth(maxOutlineDepth: number): number {
  const buttonCount = Math.max(1, maxOutlineDepth + 1);
  return Math.max(56, buttonCount * 20);
}

function hierarchyExpanderWidth(maxOutlineDepth: number): number {
  return hierarchyOutlineWidth(maxOutlineDepth) + 280;
}

function applyHierarchyIconTheme(wasmModule: WasmModule, id: number): void {
  const patchFontNames = (wasmModule as any).patch_icon_theme_default_font_names as
    | ((gridId: number, fontNames: string[]) => void)
    | undefined;
  let patchedFontFamily = false;
  if (typeof patchFontNames === "function") {
    patchFontNames(id, ["Material Icons", "MaterialIcons"]);
    patchedFontFamily = true;
  }

  const patchTextStyle = (wasmModule as any).patch_icon_theme_default_text_style as
    | ((gridId: number, fontName?: string | null, fontSize?: number | null, bold?: boolean | null, italic?: boolean | null, color?: number | null) => void)
    | undefined;
  if (!patchedFontFamily && typeof patchTextStyle === "function") {
    patchTextStyle(id, "Material Icons", null, null, null, null);
  }

  const setIconSlot = (wasmModule as any).set_icon_theme_slot as
    | ((gridId: number, slot: number, icon: string) => void)
    | undefined;
  if (typeof setIconSlot === "function") {
    setIconSlot(id, ICON_SLOT_TREE_EXPANDED, MATERIAL_ICON_EXPAND_MORE);
    setIconSlot(id, ICON_SLOT_TREE_COLLAPSED, MATERIAL_ICON_CHEVRON_RIGHT);
  }
}

function pbEncodeHierarchyOutlineConfig(maxOutlineDepth: number, maxOutlineLevel: number): Uint8Array {
  const outlineWidth = hierarchyOutlineWidth(maxOutlineDepth);
  const expanderWidth = hierarchyExpanderWidth(maxOutlineDepth);
  const layout: number[] = [];
  layout.push(...pbEncodeInt32Field(LayoutConfigFields.fixed_rows, 0));

  const style: number[] = [];
  style.push(...pbEncodeUint32Field(StyleConfigFields.background, 0xFFFFFFFF));
  style.push(...pbEncodeUint32Field(StyleConfigFields.foreground, 0xFF1C1917));
  style.push(...pbEncodeUint32Field(StyleConfigFields.alternate_background, 0xFFF5F5F4));
  style.push(...pbEncodeUint32Field(StyleConfigFields.progress_color, 0xFFF59E0B));
  style.push(...pbEncodeMessageField(StyleConfigFields.grid_lines, pbEncodeGridLinesPayload(0xFFE7E5E4)));
  style.push(...pbEncodeMessageField(StyleConfigFields.fixed, pbEncodeRegionStylePayload(0xFFF5F5F4, 0xFF44403C, 0xFFD6D3D1)));
  style.push(...pbEncodeMessageField(StyleConfigFields.frozen, pbEncodeRegionStylePayload(0xFFFFFFFF, 0xFF1C1917, 0xFFD6D3D1)));
  style.push(...pbEncodeMessageField(StyleConfigFields.header, pbEncodeHeaderStylePayload(0xFFD6D3D1)));
  style.push(...pbEncodeUint32Field(StyleConfigFields.sheet_background, 0xFFFAFAF9));
  style.push(...pbEncodeUint32Field(StyleConfigFields.sheet_border, 0xFFD6D3D1));

  const selectionStyle = pbEncodeHighlightStylePayload({
    background: 0xFFD97706,
    foreground: 0xFFFFFFFF,
    fillHandle: FillHandlePosition.FILL_HANDLE_NONE,
    fillHandleColor: 0xFFF59E0B,
  });
  const activeCellStyle = pbEncodeHighlightStylePayload({
    background: 0x22000000,
    foreground: 0xFFFFFFFF,
    borderStyle: BorderStyle.BORDER_THICK,
    borderColor: 0xFFF59E0B,
  });
  const hover: number[] = [];
  hover.push(...pbEncodeTag(HoverConfigFields.cell, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeMessageField(HoverConfigFields.cell_style, pbEncodeHighlightStylePayload({
    background: 0x1AD97706,
    borderStyle: BorderStyle.BORDER_THIN,
    borderColor: 0xFFF59E0B,
  })));
  const selection: number[] = [];
  selection.push(...pbEncodeInt32Field(SelectionConfigFields.mode, SelectionMode.SELECTION_FREE));
  selection.push(...pbEncodeMessageField(SelectionConfigFields.style, selectionStyle));
  selection.push(...pbEncodeMessageField(SelectionConfigFields.hover, new Uint8Array(hover)));
  selection.push(...pbEncodeMessageField(SelectionConfigFields.active_cell_style, activeCellStyle));

  const editing: number[] = [];
  const activation: number[] = [];
  activation.push(...pbEncodeInt32Field(EditActivationFields.trigger, EditTrigger.EDIT_TRIGGER_NONE));
  activation.push(...pbEncodeInt32Field(EditActivationFields.tab_behavior, TabBehavior.TAB_CELLS));
  editing.push(...pbEncodeMessageField(EditConfigFields.activation, new Uint8Array(activation)));
  editing.push(...pbEncodeMessageField(EditConfigFields.default_editor, defaultHostTextEditor()));

  const scrolling: number[] = [];
  scrolling.push(...pbEncodeInt32Field(ScrollConfigFields.scrollbars, ScrollBarsMode.SCROLLBAR_BOTH));
  scrolling.push(...pbEncodeTag(ScrollConfigFields.fling_enabled, 0), ...pbEncodeBool(true));
  scrolling.push(...pbEncodeFloatField(ScrollConfigFields.fling_impulse_gain, 220.0));
  scrolling.push(...pbEncodeFloatField(ScrollConfigFields.fling_friction, 0.9));

  const outline: number[] = [];
  outline.push(...pbEncodeInt32Field(OutlineConfigFields.tree_indicator, TreeIndicatorStyle.TREE_INDICATOR_CONNECTORS_LEAF));
  outline.push(...pbEncodeUint32Field(OutlineConfigFields.tree_color, 0xFFA8A29E));
  outline.push(...pbEncodeInt32Field(OutlineConfigFields.indicator_indent, 20));
  outline.push(...pbEncodeInt32Field(OutlineConfigFields.max_levels, Math.max(0, maxOutlineLevel)));
  outline.push(...pbEncodeTag(OutlineConfigFields.show_level_buttons, 0), ...pbEncodeBool(true));
  outline.push(...pbEncodeInt32Field(OutlineConfigFields.label_column, HIERARCHY_NAME_COL));
  outline.push(...pbEncodeInt32Field(OutlineConfigFields.icon_column, HIERARCHY_ICON_COL));

  const resize: number[] = [];
  resize.push(...pbEncodeTag(ResizePolicyFields.columns, 0), ...pbEncodeBool(true));
  resize.push(...pbEncodeTag(ResizePolicyFields.rows, 0), ...pbEncodeBool(false));
  const freeze: number[] = [];
  freeze.push(...pbEncodeTag(FreezePolicyFields.columns, 0), ...pbEncodeBool(true));
  freeze.push(...pbEncodeTag(FreezePolicyFields.rows, 0), ...pbEncodeBool(true));
  const headerFeatures: number[] = [];
  headerFeatures.push(...pbEncodeTag(HeaderFeaturesFields.sort, 0), ...pbEncodeBool(false));
  headerFeatures.push(...pbEncodeTag(HeaderFeaturesFields.reorder, 0), ...pbEncodeBool(false));
  headerFeatures.push(...pbEncodeTag(HeaderFeaturesFields.chooser, 0), ...pbEncodeBool(false));
  const interaction: number[] = [];
  interaction.push(...pbEncodeMessageField(InteractionConfigFields.resize, new Uint8Array(resize)));
  interaction.push(...pbEncodeMessageField(InteractionConfigFields.freeze, new Uint8Array(freeze)));
  interaction.push(...pbEncodeTag(InteractionConfigFields.auto_size_mouse, 0), ...pbEncodeBool(true));
  interaction.push(...pbEncodeMessageField(InteractionConfigFields.header_features, new Uint8Array(headerFeatures)));

  const colTop: number[] = [];
  colTop.push(...pbEncodeTag(ColIndicatorConfigFields.visible, 0), ...pbEncodeBool(true));
  colTop.push(...pbEncodeInt32Field(ColIndicatorConfigFields.band_rows, 1));
  const colTopModes: number[] = [];
  colTopModes.push(...pbEncodeInt32Field(1, ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT));
  colTop.push(...pbEncodeMessageField(ColIndicatorConfigFields.cell_modes, new Uint8Array(colTopModes)));
  colTop.push(...pbEncodeUint32Field(ColIndicatorConfigFields.background, 0xFFFAFAF9));
  colTop.push(...pbEncodeUint32Field(ColIndicatorConfigFields.foreground, 0xFF1C1917));
  colTop.push(...pbEncodeUint32Field(ColIndicatorConfigFields.grid_color, 0xFFD6D3D1));
  colTop.push(...pbEncodeTag(ColIndicatorConfigFields.allow_resize, 0), ...pbEncodeBool(true));
  const rowStart: number[] = [];
  rowStart.push(...pbEncodeTag(RowIndicatorConfigFields.visible, 0), ...pbEncodeBool(true));
  rowStart.push(...pbEncodeInt32Field(RowIndicatorConfigFields.width, expanderWidth));
  rowStart.push(...pbEncodeUint32Field(RowIndicatorConfigFields.background, 0xFFFAFAF9));
  rowStart.push(...pbEncodeUint32Field(RowIndicatorConfigFields.foreground, 0xFF57534E));
  rowStart.push(...pbEncodeUint32Field(RowIndicatorConfigFields.grid_color, 0xFFD6D3D1));
  rowStart.push(...pbEncodeTag(RowIndicatorConfigFields.auto_size, 0), ...pbEncodeBool(true));
  rowStart.push(...pbEncodeTag(RowIndicatorConfigFields.allow_resize, 0), ...pbEncodeBool(true));
  const expanderSlot: number[] = [];
  expanderSlot.push(...pbEncodeInt32Field(RowIndicatorSlotFields.kind, RowIndicatorSlotKind.ROW_INDICATOR_SLOT_EXPANDER));
  expanderSlot.push(...pbEncodeInt32Field(RowIndicatorSlotFields.width, expanderWidth));
  expanderSlot.push(...pbEncodeTag(RowIndicatorSlotFields.visible, 0), ...pbEncodeBool(true));
  rowStart.push(...pbEncodeMessageField(RowIndicatorConfigFields.slots, new Uint8Array(expanderSlot)));
  const cornerTopStart: number[] = [];
  cornerTopStart.push(...pbEncodeTag(CornerIndicatorConfigFields.visible, 0), ...pbEncodeBool(true));
  cornerTopStart.push(...pbEncodeUint32Field(CornerIndicatorConfigFields.background, 0xFFFAFAF9));
  cornerTopStart.push(...pbEncodeUint32Field(CornerIndicatorConfigFields.foreground, 0xFF57534E));
  const outlineLevelsSlot: number[] = [];
  outlineLevelsSlot.push(...pbEncodeInt32Field(CornerIndicatorSlotFields.kind, CornerIndicatorSlotKind.CORNER_SLOT_OUTLINE_LEVELS));
  outlineLevelsSlot.push(...pbEncodeInt32Field(CornerIndicatorSlotFields.width, outlineWidth));
  outlineLevelsSlot.push(...pbEncodeTag(CornerIndicatorSlotFields.visible, 0), ...pbEncodeBool(true));
  cornerTopStart.push(...pbEncodeMessageField(CornerIndicatorConfigFields.slots, new Uint8Array(outlineLevelsSlot)));
  const indicators: number[] = [];
  indicators.push(...pbEncodeMessageField(IndicatorsConfigFields.col_top, new Uint8Array(colTop)));
  indicators.push(...pbEncodeMessageField(IndicatorsConfigFields.row_start, new Uint8Array(rowStart)));
  indicators.push(...pbEncodeMessageField(IndicatorsConfigFields.corner_top_start, new Uint8Array(cornerTopStart)));
  indicators.push(...pbEncodeInt32Field(IndicatorsConfigFields.appearance, IndicatorAppearance.INDICATOR_APPEARANCE_MODERN));
  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.layout, new Uint8Array(layout)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.style, new Uint8Array(style)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.selection, new Uint8Array(selection)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.editing, new Uint8Array(editing)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.scrolling, new Uint8Array(scrolling)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.outline, new Uint8Array(outline)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.interaction, new Uint8Array(interaction)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.indicators, new Uint8Array(indicators)));
  return new Uint8Array(gridConfig);
}

function pbEncodeSalesDemoConfig(): Uint8Array {
  const layout: number[] = [];
  layout.push(...pbEncodeInt32Field(LayoutConfigFields.fixed_rows, 0));
  layout.push(...pbEncodeTag(LayoutConfigFields.extend_last_col, 0), ...pbEncodeBool(true));

  const style: number[] = [];
  style.push(...pbEncodeUint32Field(StyleConfigFields.background, 0xFFFFFFFF));
  style.push(...pbEncodeUint32Field(StyleConfigFields.foreground, 0xFF111827));
  style.push(...pbEncodeUint32Field(StyleConfigFields.alternate_background, 0xFFF9FAFB));
  style.push(...pbEncodeUint32Field(StyleConfigFields.progress_color, 0xFF818CF8));
  style.push(...pbEncodeMessageField(StyleConfigFields.grid_lines, pbEncodeGridLinesPayload(0xFFE5E7EB)));
  style.push(...pbEncodeMessageField(StyleConfigFields.fixed, pbEncodeRegionStylePayload(0xFFF3F4F6, 0xFF374151, 0xFFD1D5DB)));
  style.push(...pbEncodeMessageField(StyleConfigFields.frozen, pbEncodeRegionStylePayload(0xFFFFFFFF, 0xFF111827, 0xFFD1D5DB)));
  style.push(...pbEncodeMessageField(StyleConfigFields.header, pbEncodeHeaderStylePayload(0xFFD1D5DB)));
  style.push(...pbEncodeUint32Field(StyleConfigFields.sheet_background, 0xFFFAFAFB));
  style.push(...pbEncodeUint32Field(StyleConfigFields.sheet_border, 0xFFD1D5DB));

  const selectionStyle = pbEncodeHighlightStylePayload({
    background: 0xFF6366F1,
    foreground: 0xFFFFFFFF,
    fillHandle: FillHandlePosition.FILL_HANDLE_NONE,
    fillHandleColor: 0xFF818CF8,
  });
  const activeCellStyle = pbEncodeHighlightStylePayload({
    background: 0x22000000,
    foreground: 0xFFFFFFFF,
    borderStyle: BorderStyle.BORDER_THICK,
    borderColor: 0xFF818CF8,
  });
  const hover: number[] = [];
  hover.push(...pbEncodeTag(HoverConfigFields.row, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeTag(HoverConfigFields.column, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeTag(HoverConfigFields.cell, 0), ...pbEncodeBool(true));
  hover.push(...pbEncodeMessageField(HoverConfigFields.row_style, pbEncodeHighlightStylePayload({ background: 0x106366F1 })));
  hover.push(...pbEncodeMessageField(HoverConfigFields.column_style, pbEncodeHighlightStylePayload({ background: 0x106366F1 })));
  hover.push(...pbEncodeMessageField(HoverConfigFields.cell_style, pbEncodeHighlightStylePayload({
    background: 0x1E818CF8,
    borderStyle: BorderStyle.BORDER_THIN,
    borderColor: 0xFF818CF8,
  })));
  const selection: number[] = [];
  selection.push(...pbEncodeInt32Field(SelectionConfigFields.mode, SelectionMode.SELECTION_FREE));
  selection.push(...pbEncodeMessageField(SelectionConfigFields.style, selectionStyle));
  selection.push(...pbEncodeMessageField(SelectionConfigFields.hover, new Uint8Array(hover)));
  selection.push(...pbEncodeMessageField(SelectionConfigFields.active_cell_style, activeCellStyle));

  const editing: number[] = [];
  const activation: number[] = [];
  activation.push(...pbEncodeInt32Field(EditActivationFields.trigger, EditTrigger.EDIT_TRIGGER_NONE));
  activation.push(...pbEncodeInt32Field(EditActivationFields.tab_behavior, TabBehavior.TAB_CELLS));
  editing.push(...pbEncodeMessageField(EditConfigFields.activation, new Uint8Array(activation)));
  editing.push(...pbEncodeMessageField(EditConfigFields.default_editor, defaultHostTextEditor()));

  const scrolling: number[] = [];
  scrolling.push(...pbEncodeInt32Field(ScrollConfigFields.scrollbars, ScrollBarsMode.SCROLLBAR_BOTH));
  scrolling.push(...pbEncodeTag(ScrollConfigFields.fling_enabled, 0), ...pbEncodeBool(true));
  scrolling.push(...pbEncodeFloatField(ScrollConfigFields.fling_impulse_gain, 220.0));
  scrolling.push(...pbEncodeFloatField(ScrollConfigFields.fling_friction, 0.9));

  const outline: number[] = [];
  outline.push(...pbEncodeInt32Field(OutlineConfigFields.tree_indicator, TreeIndicatorStyle.TREE_INDICATOR_NONE));
  outline.push(...pbEncodeInt32Field(OutlineConfigFields.group_total_position, GroupTotalPosition.GROUP_TOTAL_BELOW));
  outline.push(...pbEncodeTag(OutlineConfigFields.multi_totals, 0), ...pbEncodeBool(true));
  outline.push(...pbEncodeUint32Field(OutlineConfigFields.tree_color, 0xFF9CA3AF));

  const span: number[] = [];
  span.push(...pbEncodeInt32Field(SpanConfigFields.cell_span, CellSpanMode.CELL_SPAN_BY_ROW));
  span.push(...pbEncodeInt32Field(SpanConfigFields.cell_span_fixed, CellSpanMode.CELL_SPAN_NONE));
  span.push(...pbEncodeInt32Field(SpanConfigFields.cell_span_compare, SpanCompareMode.SPAN_COMPARE_NO_CASE));

  const resize: number[] = [];
  resize.push(...pbEncodeTag(ResizePolicyFields.columns, 0), ...pbEncodeBool(true));
  resize.push(...pbEncodeTag(ResizePolicyFields.rows, 0), ...pbEncodeBool(true));
  const freeze: number[] = [];
  freeze.push(...pbEncodeTag(FreezePolicyFields.columns, 0), ...pbEncodeBool(true));
  freeze.push(...pbEncodeTag(FreezePolicyFields.rows, 0), ...pbEncodeBool(true));
  const headerFeatures: number[] = [];
  headerFeatures.push(...pbEncodeTag(HeaderFeaturesFields.sort, 0), ...pbEncodeBool(true));
  headerFeatures.push(...pbEncodeTag(HeaderFeaturesFields.reorder, 0), ...pbEncodeBool(true));
  headerFeatures.push(...pbEncodeTag(HeaderFeaturesFields.chooser, 0), ...pbEncodeBool(false));
  const interaction: number[] = [];
  interaction.push(...pbEncodeMessageField(InteractionConfigFields.resize, new Uint8Array(resize)));
  interaction.push(...pbEncodeMessageField(InteractionConfigFields.freeze, new Uint8Array(freeze)));
  interaction.push(...pbEncodeTag(InteractionConfigFields.auto_size_mouse, 0), ...pbEncodeBool(true));
  interaction.push(...pbEncodeMessageField(InteractionConfigFields.header_features, new Uint8Array(headerFeatures)));

  const rowStart: number[] = [];
  rowStart.push(...pbEncodeTag(RowIndicatorConfigFields.visible, 0), ...pbEncodeBool(true));
  rowStart.push(...pbEncodeInt32Field(RowIndicatorConfigFields.width, 40));
  rowStart.push(...pbEncodeUint32Field(RowIndicatorConfigFields.background, 0xFFF9FAFB));
  rowStart.push(...pbEncodeUint32Field(RowIndicatorConfigFields.foreground, 0xFF6B7280));
  rowStart.push(...pbEncodeUint32Field(RowIndicatorConfigFields.grid_color, 0xFFD1D5DB));
  rowStart.push(...pbEncodeTag(RowIndicatorConfigFields.allow_resize, 0), ...pbEncodeBool(true));
  const rowNumberSlot: number[] = [];
  rowNumberSlot.push(...pbEncodeInt32Field(RowIndicatorSlotFields.kind, RowIndicatorSlotKind.ROW_INDICATOR_SLOT_NUMBERS));
  rowNumberSlot.push(...pbEncodeInt32Field(RowIndicatorSlotFields.width, 40));
  rowNumberSlot.push(...pbEncodeTag(RowIndicatorSlotFields.visible, 0), ...pbEncodeBool(true));
  rowStart.push(...pbEncodeMessageField(RowIndicatorConfigFields.slots, new Uint8Array(rowNumberSlot)));
  const colTop: number[] = [];
  colTop.push(...pbEncodeTag(ColIndicatorConfigFields.visible, 0), ...pbEncodeBool(true));
  colTop.push(...pbEncodeInt32Field(ColIndicatorConfigFields.default_row_height, 28));
  colTop.push(...pbEncodeInt32Field(ColIndicatorConfigFields.band_rows, 1));
  const colTopModes: number[] = [];
  colTopModes.push(...pbEncodeInt32Field(1, ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT));
  colTopModes.push(...pbEncodeInt32Field(1, ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH));
  colTop.push(...pbEncodeMessageField(ColIndicatorConfigFields.cell_modes, new Uint8Array(colTopModes)));
  colTop.push(...pbEncodeUint32Field(ColIndicatorConfigFields.background, 0xFFF9FAFB));
  colTop.push(...pbEncodeUint32Field(ColIndicatorConfigFields.foreground, 0xFF111827));
  colTop.push(...pbEncodeUint32Field(ColIndicatorConfigFields.grid_color, 0xFFD1D5DB));
  colTop.push(...pbEncodeTag(ColIndicatorConfigFields.allow_resize, 0), ...pbEncodeBool(true));
  const indicators: number[] = [];
  indicators.push(...pbEncodeMessageField(IndicatorsConfigFields.row_start, new Uint8Array(rowStart)));
  indicators.push(...pbEncodeMessageField(IndicatorsConfigFields.col_top, new Uint8Array(colTop)));
  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.layout, new Uint8Array(layout)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.style, new Uint8Array(style)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.selection, new Uint8Array(selection)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.editing, new Uint8Array(editing)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.scrolling, new Uint8Array(scrolling)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.outline, new Uint8Array(outline)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.span, new Uint8Array(span)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.interaction, new Uint8Array(interaction)));
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.indicators, new Uint8Array(indicators)));
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
    const result = grid.loadData(salesData, {
      autoCreateColumns: false,
    });
    if (result.status === LoadDataStatus.LOAD_FAILED) {
      throw new Error("LoadData failed for embedded sales demo");
    }
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, SALES_COLUMN_SETUP));
    if (typeof wasmModule.volvox_grid_configure === "function") {
      wasmModule.volvox_grid_configure(gridHandle, pbEncodeSalesDemoConfig());
    }
    grid.selectionMode = SelectionMode.SELECTION_FREE;
    grid.setHeaderFeatures({ sort: true, reorder: true, chooser: false });
    grid.setColFormat(4, "$#,##0");
    grid.setColFormat(5, "$#,##0");
    grid.setColProgressColor(6, 0xFF818CF8);
    grid.setColDropdown(8, dropdownFromLabels(SALES_STATUS_ITEMS));
    grid.flingImpulseGain = 220.0;
    grid.flingFriction = 0.9;
    grid.subtotal(AggregateType.AGG_CLEAR, 0, 0, "", 0, 0, false);
    applySalesSubtotalDecorations(grid, grid.subtotal(AggregateType.AGG_SUM, -1, 4, "Grand Total", 0xFFEEF2FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(AggregateType.AGG_SUM, 0, 4, "", 0xFFF5F3FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(AggregateType.AGG_SUM, 1, 4, "", 0xFFF8F7FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(AggregateType.AGG_SUM, -1, 5, "Grand Total", 0xFFEEF2FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(AggregateType.AGG_SUM, 0, 5, "", 0xFFF5F3FF, 0xFF111827, true).rows);
    applySalesSubtotalDecorations(grid, grid.subtotal(AggregateType.AGG_SUM, 1, 5, "", 0xFFF8F7FF, 0xFF111827, true).rows);
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
    const outlineLevels = hierarchyRowDepths(rawRows);
    const minOutlineLevel = 0;
    const maxOutlineLevel = outlineLevels.reduce((maxLevel, level) => Math.max(maxLevel, level), 0);
    const maxOutlineDepth = Math.max(0, maxOutlineLevel - minOutlineLevel);
    grid.colCount = HIERARCHY_COLS;
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, HIERARCHY_COLUMN_SETUP));
    const loadTree = (wasmModule as HierarchyTreeWasmModule).volvox_tree_load_tree_pb;
    if (typeof loadTree !== "function") {
      throw new Error("Hierarchy demo requires VolvoxTreeService WASM support");
    }
    const response = loadTree(pbEncodeHierarchyLoadTreeRequest(id, rawRows));
    if (!(response instanceof Uint8Array) || response.length === 0) {
      throw new Error("VolvoxTreeService.LoadTree failed for embedded hierarchy demo");
    }
    if (typeof wasmModule.volvox_grid_configure === "function") {
      wasmModule.volvox_grid_configure(
        BigInt(id),
        pbEncodeHierarchyOutlineConfig(maxOutlineDepth, maxOutlineLevel),
      );
    }
    applyHierarchyIconTheme(wasmModule, id);

    grid.selectionMode = SelectionMode.SELECTION_FREE;
    grid.setHeaderFeatures({ sort: false, reorder: false, chooser: false });
    grid.flingImpulseGain = 220.0;
    grid.flingFriction = 0.9;
    grid.editable = false;
    grid.invalidate();
  } finally {
    if (id !== prevId) {
      grid.useGrid(prevId);
    }
  }
}

function barcodeKey(value: string): string {
  return value.replace(/[^0-9a-z]/gi, "").toUpperCase();
}

function barcodeTextEncodingFromRecord(record: BarcodeJsonRow, fallback: number): number {
  switch (barcodeKey(record.TextEncoding ?? "")) {
    case "UTF8":
      return BarcodeTextEncoding.BARCODE_TEXT_UTF8;
    case "GS1":
      return BarcodeTextEncoding.BARCODE_TEXT_GS1;
    case "AUTO":
      return BarcodeTextEncoding.BARCODE_TEXT_AUTO;
    default:
      return fallback;
  }
}

function barcodeTextEncodingLabel(textEncoding: number): string {
  switch (textEncoding) {
    case BarcodeTextEncoding.BARCODE_TEXT_UTF8:
      return "UTF8";
    case BarcodeTextEncoding.BARCODE_TEXT_GS1:
      return "GS1";
    default:
      return "AUTO";
  }
}

function barcodeTextEncodingDisplay(record: BarcodeJsonRow): string {
  if (!record.TextEncoding) {
    return "";
  }
  return barcodeTextEncodingLabel(barcodeTextEncodingFromRecord(record, BarcodeTextEncoding.BARCODE_TEXT_AUTO));
}

function barcodeQrEccFromRecord(record: BarcodeJsonRow, fallback: number): number {
  switch (barcodeKey(record.QrEcc ?? "")) {
    case "LOW":
      return BarcodeQrErrorCorrection.QR_ECC_LOW;
    case "MEDIUM":
      return BarcodeQrErrorCorrection.QR_ECC_MEDIUM;
    case "QUARTILE":
      return BarcodeQrErrorCorrection.QR_ECC_QUARTILE;
    case "HIGH":
      return BarcodeQrErrorCorrection.QR_ECC_HIGH;
    case "DEFAULT":
      return BarcodeQrErrorCorrection.QR_ECC_DEFAULT;
    default:
      return fallback;
  }
}

function barcodeQrEccLabel(qrEcc: number): string {
  switch (qrEcc) {
    case BarcodeQrErrorCorrection.QR_ECC_LOW:
      return "LOW";
    case BarcodeQrErrorCorrection.QR_ECC_MEDIUM:
      return "MEDIUM";
    case BarcodeQrErrorCorrection.QR_ECC_QUARTILE:
      return "QUARTILE";
    case BarcodeQrErrorCorrection.QR_ECC_HIGH:
      return "HIGH";
    default:
      return "DEFAULT";
  }
}

function barcodeDemoPlan(record: BarcodeJsonRow): BarcodeDemoPlan {
  const plan: BarcodeDemoPlan = {
    symbology: BarcodeSymbology.BARCODE_NONE,
    checkDigit: BarcodeCheckDigitMode.CHECK_DIGIT_DEFAULT,
    textEncoding: BarcodeTextEncoding.BARCODE_TEXT_AUTO,
    qrEcc: BarcodeQrErrorCorrection.QR_ECC_DEFAULT,
    foreground: 0xFF111827,
    background: 0xFFFFFFFF,
    alignment: ImageAlignment.IMG_ALIGN_CENTER_CENTER,
    moduleSize: 0,
    quietZone: 0,
    barHeight: 0,
    narrowBarWidth: 0,
    captionPosition: BarcodeCaptionPosition.CAPTION_BOTTOM,
    captionColor: 0xFF334155,
    rowHeight: 96,
    optionsText: "auto",
  };

  switch (barcodeKey(record.Symbology)) {
    case "QR":
    case "QRCODE":
      plan.symbology = BarcodeSymbology.BARCODE_QR;
      plan.textEncoding = barcodeTextEncodingFromRecord(record, BarcodeTextEncoding.BARCODE_TEXT_AUTO);
      plan.qrEcc = barcodeQrEccFromRecord(record, BarcodeQrErrorCorrection.QR_ECC_DEFAULT);
      plan.background = 0xFFF8FAFC;
      plan.alignment = ImageAlignment.IMG_ALIGN_CENTER_CENTER;
      plan.quietZone = 3;
      plan.rowHeight = 150;
      plan.captionColor = 0xFF1D4ED8;
      plan.optionsText = `text=${barcodeTextEncodingLabel(plan.textEncoding)}, qr_ecc=${barcodeQrEccLabel(plan.qrEcc)}, quiet=3, size=auto`;
      break;
    case "CODE128": {
      plan.symbology = BarcodeSymbology.BARCODE_CODE128;
      plan.textEncoding = barcodeTextEncodingFromRecord(record, BarcodeTextEncoding.BARCODE_TEXT_AUTO);
      plan.background = 0xFFECFDF5;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 10;
      plan.captionColor = 0xFF047857;
      plan.optionsText = `text=${barcodeTextEncodingLabel(plan.textEncoding)}, check=AUTO, quiet=10, size=auto`;
      break;
    }
    case "CODE39":
      plan.symbology = BarcodeSymbology.BARCODE_CODE39;
      plan.checkDigit = BarcodeCheckDigitMode.CHECK_DIGIT_GENERATE;
      plan.foreground = 0xFF7C2D12;
      plan.background = 0xFFFFF7ED;
      plan.quietZone = 8;
      plan.captionPosition = BarcodeCaptionPosition.CAPTION_TOP;
      plan.captionColor = 0xFFC2410C;
      plan.optionsText = "check=GENERATE, quiet=8, size=auto, caption=TOP";
      break;
    case "CODE93":
      plan.symbology = BarcodeSymbology.BARCODE_CODE93;
      plan.foreground = 0xFF312E81;
      plan.background = 0xFFEEF2FF;
      plan.quietZone = 8;
      plan.optionsText = "quiet=8, size=auto";
      break;
    case "CODE11":
      plan.symbology = BarcodeSymbology.BARCODE_CODE11;
      plan.foreground = 0xFF3F3F46;
      plan.background = 0xFFF4F4F5;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 10;
      plan.optionsText = "quiet=10, size=auto";
      break;
    case "EAN13":
      plan.symbology = BarcodeSymbology.BARCODE_EAN13;
      plan.foreground = 0xFF1F2937;
      plan.quietZone = 12;
      plan.optionsText = "check=AUTO, quiet=12, size=auto";
      break;
    case "EAN8":
      plan.symbology = BarcodeSymbology.BARCODE_EAN8;
      plan.foreground = 0xFF164E63;
      plan.background = 0xFFECFEFF;
      plan.quietZone = 10;
      plan.optionsText = "check=AUTO, quiet=10, size=auto";
      break;
    case "UPCA":
      plan.symbology = BarcodeSymbology.BARCODE_UPC_A;
      plan.foreground = 0xFF365314;
      plan.background = 0xFFF7FEE7;
      plan.quietZone = 12;
      plan.optionsText = "check=AUTO, quiet=12, size=auto";
      break;
    case "UPCE":
      plan.symbology = BarcodeSymbology.BARCODE_UPC_E;
      plan.foreground = 0xFF7F1D1D;
      plan.background = 0xFFFEF2F2;
      plan.quietZone = 10;
      plan.optionsText = "check=AUTO, quiet=10, size=auto";
      break;
    case "EANSUPP":
    case "EANSUPPLEMENT":
    case "EANSUPPLEMENTAL":
      plan.symbology = BarcodeSymbology.BARCODE_EAN_SUPP;
      plan.foreground = 0xFF581C87;
      plan.background = 0xFFFAF5FF;
      plan.quietZone = 8;
      plan.optionsText = "quiet=8, size=auto";
      break;
    case "ITF":
      plan.symbology = BarcodeSymbology.BARCODE_ITF;
      plan.checkDigit = BarcodeCheckDigitMode.CHECK_DIGIT_NONE;
      plan.foreground = 0xFF0F766E;
      plan.background = 0xFFF0FDFA;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 12;
      plan.optionsText = "check=NONE, quiet=12, size=auto";
      break;
    case "STF":
      plan.symbology = BarcodeSymbology.BARCODE_STF;
      plan.foreground = 0xFF854D0E;
      plan.background = 0xFFFEFCE8;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 10;
      plan.optionsText = "quiet=10, size=auto";
      break;
    case "CODABAR":
      plan.symbology = BarcodeSymbology.BARCODE_CODABAR;
      plan.foreground = 0xFFBE123C;
      plan.background = 0xFFFFF1F2;
      plan.quietZone = 10;
      plan.captionPosition = BarcodeCaptionPosition.CAPTION_NONE;
      plan.optionsText = "quiet=10, size=auto, caption=NONE";
      break;
    default:
      throw new Error(`unknown barcode symbology: ${record.Symbology}`);
  }

  return plan;
}

function setupBarcodesJsonDemo(grid: VolvoxGrid, wasmModule: WasmModule, id: number): void {
  const prevId = grid.id;
  if (id !== prevId) {
    grid.useGrid(id);
  }

  try {
    const barcodeData = grid.getDemoData("barcodes");
    if (barcodeData.length === 0) {
      throw new Error("embedded barcodes demo data is empty");
    }
    const records = JSON.parse(PB_TEXT_DECODER.decode(barcodeData)) as BarcodeJsonRow[];
    const plans = records.map((record) => barcodeDemoPlan(record));

    grid.colCount = BARCODE_COLS;
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, BARCODE_COLUMN_SETUP));
    const result = grid.loadData(barcodeData, {
      autoCreateColumns: false,
    });
    if (result.status === LoadDataStatus.LOAD_FAILED) {
      throw new Error("LoadData failed for embedded barcodes demo");
    }
    wasmModule.volvox_grid_define_columns_pb(pbEncodeDefineColumnsRequest(id, BARCODE_COLUMN_SETUP));
    if (typeof wasmModule.volvox_grid_configure === "function") {
      wasmModule.volvox_grid_configure(BigInt(id), pbEncodeSalesDemoConfig());
    }
    wasmModule.volvox_grid_define_rows_pb(
      pbEncodeDefineRowsRequest(
        id,
        plans.map((plan) => ({ height: plan.rowHeight })),
      ),
    );

    const smallTextStyle: DemoCellStyleSpec = {
      foreground: 0xFF475569,
    };
    const cells: Uint8Array[] = [];
    records.forEach((record, index) => {
      const plan = plans[index];
      cells.push(pbEncodeCellUpdate({
        row: index,
        col: 2,
        valueText: barcodeTextEncodingDisplay(record),
        style: {
          foreground: 0xFF475569,
          align: Align.ALIGN_CENTER_CENTER,
        },
      }));
      cells.push(pbEncodeCellUpdate({
        row: index,
        col: 3,
        valueText: `${record.Label}\n${plan.optionsText}`,
        style: smallTextStyle,
      }));
      cells.push(pbEncodeCellUpdate({
        row: index,
        col: 4,
        valueText: record.Value,
        style: {
          background: plan.background,
          align: Align.ALIGN_CENTER_CENTER,
          padding: { left: 4, top: 4, right: 4, bottom: 4 },
          borderAll: {
            style: BorderStyle.BORDER_THIN,
            color: 0xFFD1D5DB,
          },
        },
        barcode: pbEncodeBarcodeData(record, plan),
      }));
      cells.push(pbEncodeCellUpdate({
        row: index,
        col: 5,
        valueText: record.Notes,
        style: smallTextStyle,
      }));
    });

    const updateCells = (wasmModule as any).volvox_grid_update_cells_pb as
      | ((request: Uint8Array) => Uint8Array)
      | undefined;
    if (typeof updateCells !== "function") {
      throw new Error("volvox_grid_update_cells_pb is not available");
    }
    updateCells(pbEncodeUpdateCellsRequest(id, cells, true));

    grid.selectionMode = SelectionMode.SELECTION_FREE;
    grid.setHeaderFeatures({ sort: true, reorder: true, chooser: false });
    grid.flingImpulseGain = 220.0;
    grid.flingFriction = 0.9;
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
  hoverConfig.push(...pbEncodeTag(HoverConfigFields.row, 0), ...pbEncodeVarint((nextMode & HOVER_ROW) !== 0 ? 1n : 0n));
  hoverConfig.push(...pbEncodeTag(HoverConfigFields.column, 0), ...pbEncodeVarint((nextMode & HOVER_COLUMN) !== 0 ? 1n : 0n));
  hoverConfig.push(...pbEncodeTag(HoverConfigFields.cell, 0), ...pbEncodeVarint((nextMode & HOVER_CELL) !== 0 ? 1n : 0n));
  const selectionConfig: number[] = [];
  selectionConfig.push(...pbEncodeMessageField(SelectionConfigFields.hover, new Uint8Array(hoverConfig)));

  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(GridConfigFields.selection, new Uint8Array(selectionConfig)));
  return new Uint8Array(gridConfig);
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

  // Register Canvas2D text renderer only when the built-in engine is absent (Lite mode)
  const hasBuiltinText = typeof (wasmModule as any).has_builtin_text_engine === "function"
    && (wasmModule as any).has_builtin_text_engine();
  let canvas2DRenderer: any = null;

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

  if (!hasBuiltinText && typeof (wasmModule as any).set_text_renderer === "function") {
    canvas2DRenderer = createCanvas2DTextRenderer(wasmModule);
    canvas2DRenderer.setCacheSize(selectedTextLayoutCacheCap());
    registerCanvas2DTextRenderer(canvas2DRenderer);
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
    if (!hasBuiltinText && typeof (wasmModule as any).set_grid_text_renderer === "function") {
      const renderer = canvas2DRenderer ?? createCanvas2DTextRenderer(wasmModule);
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
  if (!hasBuiltinText && typeof (wasmModule as any).set_grid_text_renderer === "function") {
    const renderer = canvas2DRenderer ?? createCanvas2DTextRenderer(wasmModule);
    registerCanvas2DTextRenderer(renderer, grid.id);
  }
  setupDefaultInput(grid, wasmModule, canvas);
  grid.onZoomChange = () => { updateStatus(); };
  applyAndroidLikeDemoStyle(grid.id);
  grid.captureZoomBase();
  if (typeof (wasmModule as any).get_render_layer_mask_lo === "function") {
    layerMask = normalizeLayerMask(Number((wasmModule as any).get_render_layer_mask_lo(grid.id)));
  }
  const demoFontsReady = loadDemoFontsInBackground(wasmModule);

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

    const autoSizeGrid = (wasmModule as any).volvox_grid_auto_size as
      | ((gridId: bigint, colFrom: number, colTo: number, equal: boolean, maxWidth: number) => Uint8Array)
      | undefined;
    if (typeof autoSizeGrid === "function") {
      autoSizeGrid(BigInt(id), 0, HIERARCHY_COLS - 1, false, 0);
      if (grid.id === id) {
        grid.invalidate();
      }
      hierarchyFontAutosizedGridIds.add(id);
      return;
    }

    const prevId = grid.id;
    if (id !== prevId) {
      grid.useGrid(id);
    }

    try {
      grid.autoSize(0, HIERARCHY_COLS - 1);
      grid.invalidate();
      hierarchyFontAutosizedGridIds.add(id);
    } finally {
      if (id !== prevId) {
        grid.useGrid(prevId);
      }
    }
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
    grid.rendererMode = activeRendererMode;
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
        wasmModule.demo_setup_stress_grid(id);
        break;
      case "sales":
        setupSalesJsonDemo(grid, wasmModule, id);
        break;
      case "hierarchy":
        setupHierarchyJsonDemo(grid, wasmModule, id);
        break;
      case "barcodes":
        setupBarcodesJsonDemo(grid, wasmModule, id);
        break;
    }

    setGridHoverMode(id, chkHover.checked ? hoverModeForDemo(mode) : HOVER_NONE);
    wasmModule.set_fast_scroll_enabled(id, true);
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
