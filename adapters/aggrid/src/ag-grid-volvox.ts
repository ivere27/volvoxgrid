import {
  VolvoxGrid,
  type VolvoxGridBeforeEditDetails,
  type VolvoxGridBeforeSortDetails,
  type VolvoxGridCellEditValidatingDetails,
} from "volvoxgrid";
import { setupDefaultInput } from "volvoxgrid/default-input.js";
import {
  Align,
  BorderStyle,
  CheckedState,
  SortOrder,
} from "volvoxgrid/generated/volvoxgrid_ffi.js";
import {
  normalizeColumnDefs,
  type ColumnLayout,
  type NormalizedColDef,
} from "./col-def-mapper.js";
import { mapCellStyles, mapRowDataToMatrix, type RowKind } from "./data-mapper.js";
import { VolvoxGridEventMapper } from "./event-mapper.js";
import { VolvoxGridApi } from "./grid-api.js";
import {
  applyColumnIndicatorTopConfig,
  applyGridOptionsToVolvox,
  type ColumnIndicatorCellConfig,
} from "./grid-options-mapper.js";
import {
  encodeLoadTableRequest,
  encodeDefineColumnAlignmentsRequest,
  encodeDefineBooleanColumnsRequest,
  encodeUpdateCellBordersRequest,
  encodeUpdateCheckedCellsRequest,
  type CellBorderUpdate,
} from "./proto-utils.js";
import { applyTheme, type PaddingPreset } from "./theme-mapper.js";
import type {
  AgGridVolvoxParams,
  CellStyle,
  ColDef,
  GridApiLike,
  GridOptions,
  RowData,
} from "./types.js";

const DEFAULT_COLUMN_WIDTH = 200;

const AG_TO_VV_ICON_SLOT: Array<{
  agKey: string;
  vvKey: string;
}> = [
  { agKey: "sortAscending", vvKey: "sortAscending" },
  { agKey: "sortDescending", vvKey: "sortDescending" },
  { agKey: "sortUnSort", vvKey: "sortNone" },
  { agKey: "groupExpanded", vvKey: "treeExpanded" },
  { agKey: "groupContracted", vvKey: "treeCollapsed" },
  { agKey: "menu", vvKey: "menu" },
  { agKey: "filter", vvKey: "filter" },
  { agKey: "filterActive", vvKey: "filterActive" },
  { agKey: "columns", vvKey: "columns" },
  { agKey: "rowDrag", vvKey: "dragHandle" },
  { agKey: "checkboxChecked", vvKey: "checkboxChecked" },
  { agKey: "checkboxUnchecked", vvKey: "checkboxUnchecked" },
  { agKey: "checkboxIndeterminate", vvKey: "checkboxIndeterminate" },
];

interface ResolvedPadding {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

interface HeaderMarkSpec {
  colorArgb: number;
  widthPx: number;
  heightMode: "ratio" | "px";
  heightValue: number;
}

interface ResolvedCellBorderEdge {
  style?: number;
  colorArgb?: number;
}

interface ResolvedCellBorder {
  all?: ResolvedCellBorderEdge;
  top?: ResolvedCellBorderEdge;
  right?: ResolvedCellBorderEdge;
  bottom?: ResolvedCellBorderEdge;
  left?: ResolvedCellBorderEdge;
}

function deriveColumnDefs<TData extends RowData>(rowData: TData[]): ColDef<TData>[] {
  const first = rowData[0];
  if (first == null) {
    return [];
  }
  return Object.keys(first).map((field) => ({
    field,
    headerName: field,
    sortable: true,
    resizable: true,
  }));
}

function clampColumnWidth(width: number, min?: number, max?: number): number {
  let w = Math.max(16, Math.round(width));
  if (typeof min === "number") {
    w = Math.max(w, Math.round(min));
  }
  if (typeof max === "number" && max > 0) {
    w = Math.min(w, Math.round(max));
  }
  return w;
}

function clampPadding(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.round(value));
}

function parsePixelValue(raw: unknown): number | undefined {
  if (typeof raw === "number") {
    if (!Number.isFinite(raw)) {
      return undefined;
    }
    return Math.round(raw);
  }
  if (typeof raw !== "string") {
    return undefined;
  }
  const value = raw.trim();
  if (value.length === 0) {
    return undefined;
  }
  const normalized = value.endsWith("px") ? value.slice(0, -2).trim() : value;
  if (!/^-?\d+(\.\d+)?$/.test(normalized)) {
    return undefined;
  }
  const parsed = Number.parseFloat(normalized);
  if (!Number.isFinite(parsed)) {
    return undefined;
  }
  return Math.round(parsed);
}

function parsePaddingShorthand(raw: unknown): ResolvedPadding | undefined {
  if (typeof raw === "number") {
    const n = Math.round(raw);
    return {
      left: n,
      top: n,
      right: n,
      bottom: n,
    };
  }
  if (typeof raw !== "string") {
    return undefined;
  }
  const tokens = raw.trim().split(/\s+/).filter((token) => token.length > 0);
  if (tokens.length === 0 || tokens.length > 4) {
    return undefined;
  }
  const values = tokens.map((token) => parsePixelValue(token));
  if (values.some((v) => typeof v !== "number")) {
    return undefined;
  }
  if (values.length === 1) {
    const v = values[0] as number;
    return { left: v, top: v, right: v, bottom: v };
  }
  if (values.length === 2) {
    const topBottom = values[0] as number;
    const leftRight = values[1] as number;
    return { left: leftRight, top: topBottom, right: leftRight, bottom: topBottom };
  }
  if (values.length === 3) {
    const top = values[0] as number;
    const leftRight = values[1] as number;
    const bottom = values[2] as number;
    return { left: leftRight, top, right: leftRight, bottom };
  }
  return {
    left: values[3] as number,
    top: values[0] as number,
    right: values[1] as number,
    bottom: values[2] as number,
  };
}

function readStyleValue(style: CellStyle, keys: string[]): unknown {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(style, key)) {
      const value = style[key];
      if (value != null) {
        return value;
      }
    }
  }
  return undefined;
}

function resolvePaddingFromCellStyle(
  style: CellStyle,
  fallback: PaddingPreset,
): ResolvedPadding | undefined {
  let left = fallback.left;
  let top = fallback.top;
  let right = fallback.right;
  let bottom = fallback.bottom;
  let changed = false;

  const paddingShorthand = parsePaddingShorthand(readStyleValue(style, ["padding"]));
  if (paddingShorthand != null) {
    left = paddingShorthand.left;
    top = paddingShorthand.top;
    right = paddingShorthand.right;
    bottom = paddingShorthand.bottom;
    changed = true;
  }

  const leftValue = parsePixelValue(readStyleValue(style, ["paddingLeft", "padding-left"]));
  if (typeof leftValue === "number") {
    left = leftValue;
    changed = true;
  }
  const topValue = parsePixelValue(readStyleValue(style, ["paddingTop", "padding-top"]));
  if (typeof topValue === "number") {
    top = topValue;
    changed = true;
  }
  const rightValue = parsePixelValue(readStyleValue(style, ["paddingRight", "padding-right"]));
  if (typeof rightValue === "number") {
    right = rightValue;
    changed = true;
  }
  const bottomValue = parsePixelValue(readStyleValue(style, ["paddingBottom", "padding-bottom"]));
  if (typeof bottomValue === "number") {
    bottom = bottomValue;
    changed = true;
  }

  if (!changed) {
    return undefined;
  }
  return {
    left: clampPadding(left),
    top: clampPadding(top),
    right: clampPadding(right),
    bottom: clampPadding(bottom),
  };
}

function parseHexColorArgb(raw: string): number | undefined {
  const value = raw.trim();
  if (!value.startsWith("#")) {
    return undefined;
  }
  const hex = value.slice(1);
  if (/^[0-9a-fA-F]{3}$/.test(hex)) {
    const r = parseInt(`${hex[0]}${hex[0]}`, 16);
    const g = parseInt(`${hex[1]}${hex[1]}`, 16);
    const b = parseInt(`${hex[2]}${hex[2]}`, 16);
    return (0xff000000 | (r << 16) | (g << 8) | b) >>> 0;
  }
  if (/^[0-9a-fA-F]{4}$/.test(hex)) {
    const r = parseInt(`${hex[0]}${hex[0]}`, 16);
    const g = parseInt(`${hex[1]}${hex[1]}`, 16);
    const b = parseInt(`${hex[2]}${hex[2]}`, 16);
    const a = parseInt(`${hex[3]}${hex[3]}`, 16);
    return ((a << 24) | (r << 16) | (g << 8) | b) >>> 0;
  }
  if (/^[0-9a-fA-F]{6}$/.test(hex)) {
    const rgb = parseInt(hex, 16);
    return (0xff000000 | rgb) >>> 0;
  }
  if (/^[0-9a-fA-F]{8}$/.test(hex)) {
    const rr = parseInt(hex.slice(0, 2), 16);
    const gg = parseInt(hex.slice(2, 4), 16);
    const bb = parseInt(hex.slice(4, 6), 16);
    const aa = parseInt(hex.slice(6, 8), 16);
    return ((aa << 24) | (rr << 16) | (gg << 8) | bb) >>> 0;
  }
  return undefined;
}

function parseCssColorLiteralArgb(raw: string): number | undefined {
  const value = raw.trim();
  if (value.length === 0) {
    return undefined;
  }
  const fromHex = parseHexColorArgb(value);
  if (typeof fromHex === "number") {
    return fromHex;
  }
  const fromRgb = parseRgbFunctionColor(value);
  if (typeof fromRgb === "number") {
    return fromRgb;
  }
  return undefined;
}

function tokenizeCssValue(raw: string): string[] {
  const out: string[] = [];
  let current = "";
  let depth = 0;
  for (let i = 0; i < raw.length; i += 1) {
    const ch = raw[i];
    if (ch === "(") {
      depth += 1;
      current += ch;
      continue;
    }
    if (ch === ")") {
      depth = Math.max(0, depth - 1);
      current += ch;
      continue;
    }
    if (/\s/.test(ch) && depth === 0) {
      if (current.length > 0) {
        out.push(current);
        current = "";
      }
      continue;
    }
    current += ch;
  }
  if (current.length > 0) {
    out.push(current);
  }
  return out;
}

function parseBorderWidthPx(raw: string): number | undefined {
  const value = raw.trim().toLowerCase();
  if (value === "thin") {
    return 1;
  }
  if (value === "medium") {
    return 2;
  }
  if (value === "thick") {
    return 3;
  }
  const parsed = parseCssPixelLength(value);
  return typeof parsed === "number" ? parsed : undefined;
}

function parseBorderStyleKeyword(raw: string, widthPx?: number): number | undefined {
  const value = raw.trim().toLowerCase();
  if (value.length === 0) {
    return undefined;
  }
  if (value === "none" || value === "hidden") {
    return BorderStyle.BORDER_NONE;
  }
  if (value === "dotted") {
    return BorderStyle.BORDER_DOTTED;
  }
  if (value === "dashed") {
    return BorderStyle.BORDER_DASHED;
  }
  if (value === "double") {
    return BorderStyle.BORDER_DOUBLE;
  }
  if (value === "inset" || value === "outset" || value === "ridge" || value === "groove") {
    // The current proto no longer exposes raised/inset border enums.
    // Preserve width intent with the nearest supported flat border style.
    return (widthPx ?? 1) >= 2 ? BorderStyle.BORDER_THICK : BorderStyle.BORDER_THIN;
  }
  if (value === "solid") {
    return (widthPx ?? 1) >= 2 ? BorderStyle.BORDER_THICK : BorderStyle.BORDER_THIN;
  }
  return undefined;
}

function parseBorderDeclaration(raw: unknown): ResolvedCellBorderEdge | undefined {
  if (typeof raw !== "string") {
    return undefined;
  }
  const tokens = tokenizeCssValue(raw.trim());
  if (tokens.length === 0) {
    return undefined;
  }

  let widthPx: number | undefined;
  let styleToken: string | undefined;
  let colorArgb: number | undefined;
  for (const token of tokens) {
    if (typeof widthPx !== "number") {
      const parsedWidth = parseBorderWidthPx(token);
      if (typeof parsedWidth === "number") {
        widthPx = parsedWidth;
      }
    }
    if (typeof styleToken !== "string") {
      const normalized = token.trim().toLowerCase();
      if (
        normalized === "none"
        || normalized === "hidden"
        || normalized === "solid"
        || normalized === "dotted"
        || normalized === "dashed"
        || normalized === "double"
        || normalized === "inset"
        || normalized === "outset"
        || normalized === "ridge"
        || normalized === "groove"
      ) {
        styleToken = normalized;
      }
    }
    if (typeof colorArgb !== "number") {
      const parsedColor = parseCssColorLiteralArgb(token);
      if (typeof parsedColor === "number") {
        colorArgb = parsedColor;
      }
    }
  }

  let style = typeof styleToken === "string"
    ? parseBorderStyleKeyword(styleToken, widthPx)
    : undefined;

  if (typeof style !== "number") {
    if (typeof widthPx === "number" || typeof colorArgb === "number") {
      style = (widthPx ?? 1) >= 2 ? BorderStyle.BORDER_THICK : BorderStyle.BORDER_THIN;
    }
  }

  if (typeof style !== "number" && typeof colorArgb !== "number") {
    return undefined;
  }
  const out: ResolvedCellBorderEdge = {};
  if (typeof style === "number") {
    out.style = style;
  }
  if (typeof colorArgb === "number") {
    out.colorArgb = colorArgb;
  }
  return out;
}

function mergeBorderEdge(
  base: ResolvedCellBorderEdge | undefined,
  patch: ResolvedCellBorderEdge | undefined,
): ResolvedCellBorderEdge | undefined {
  if (base == null) {
    return patch;
  }
  if (patch == null) {
    return base;
  }
  return {
    style: patch.style ?? base.style,
    colorArgb: patch.colorArgb ?? base.colorArgb,
  };
}

function applyBorderPartOverrides(args: {
  target: ResolvedCellBorderEdge | undefined;
  styleValue: unknown;
  widthValue: unknown;
  colorValue: unknown;
}): ResolvedCellBorderEdge | undefined {
  let target = args.target;
  const styleRaw = typeof args.styleValue === "string" ? args.styleValue : "";
  const widthRaw =
    typeof args.widthValue === "number" || typeof args.widthValue === "string"
      ? String(args.widthValue)
      : "";
  const colorRaw = typeof args.colorValue === "string" ? args.colorValue : "";

  const widthPx = widthRaw.length > 0 ? parseBorderWidthPx(widthRaw) : undefined;
  const parsedStyle = styleRaw.length > 0 ? parseBorderStyleKeyword(styleRaw, widthPx) : undefined;
  const parsedColor = colorRaw.length > 0 ? parseCssColorLiteralArgb(colorRaw) : undefined;

  if (
    typeof parsedStyle !== "number"
    && typeof parsedColor !== "number"
    && typeof widthPx !== "number"
  ) {
    return target;
  }

  if (target == null) {
    target = {};
  }
  if (typeof parsedStyle === "number") {
    target.style = parsedStyle;
  } else if (typeof widthPx === "number" && target.style == null) {
    target.style = widthPx >= 2 ? BorderStyle.BORDER_THICK : BorderStyle.BORDER_THIN;
  }
  if (typeof parsedColor === "number") {
    target.colorArgb = parsedColor;
  }
  return target;
}

function resolveBorderFromCellStyle(style: CellStyle): ResolvedCellBorder | undefined {
  let all = parseBorderDeclaration(readStyleValue(style, ["border"]));
  all = applyBorderPartOverrides({
    target: all,
    styleValue: readStyleValue(style, ["borderStyle", "border-style"]),
    widthValue: readStyleValue(style, ["borderWidth", "border-width"]),
    colorValue: readStyleValue(style, ["borderColor", "border-color"]),
  });

  let top = parseBorderDeclaration(readStyleValue(style, ["borderTop", "border-top"]));
  let right = parseBorderDeclaration(readStyleValue(style, ["borderRight", "border-right"]));
  let bottom = parseBorderDeclaration(readStyleValue(style, ["borderBottom", "border-bottom"]));
  let left = parseBorderDeclaration(readStyleValue(style, ["borderLeft", "border-left"]));

  top = applyBorderPartOverrides({
    target: top,
    styleValue: readStyleValue(style, ["borderTopStyle", "border-top-style"]),
    widthValue: readStyleValue(style, ["borderTopWidth", "border-top-width"]),
    colorValue: readStyleValue(style, ["borderTopColor", "border-top-color"]),
  });
  right = applyBorderPartOverrides({
    target: right,
    styleValue: readStyleValue(style, ["borderRightStyle", "border-right-style"]),
    widthValue: readStyleValue(style, ["borderRightWidth", "border-right-width"]),
    colorValue: readStyleValue(style, ["borderRightColor", "border-right-color"]),
  });
  bottom = applyBorderPartOverrides({
    target: bottom,
    styleValue: readStyleValue(style, ["borderBottomStyle", "border-bottom-style"]),
    widthValue: readStyleValue(style, ["borderBottomWidth", "border-bottom-width"]),
    colorValue: readStyleValue(style, ["borderBottomColor", "border-bottom-color"]),
  });
  left = applyBorderPartOverrides({
    target: left,
    styleValue: readStyleValue(style, ["borderLeftStyle", "border-left-style"]),
    widthValue: readStyleValue(style, ["borderLeftWidth", "border-left-width"]),
    colorValue: readStyleValue(style, ["borderLeftColor", "border-left-color"]),
  });

  // Edge-specific color shorthand without edge style can still override color.
  const topColor = readStyleValue(style, ["borderTopColor", "border-top-color"]);
  if (typeof topColor === "string") {
    const parsed = parseCssColorLiteralArgb(topColor);
    if (typeof parsed === "number") {
      top = mergeBorderEdge(top, { colorArgb: parsed });
    }
  }
  const rightColor = readStyleValue(style, ["borderRightColor", "border-right-color"]);
  if (typeof rightColor === "string") {
    const parsed = parseCssColorLiteralArgb(rightColor);
    if (typeof parsed === "number") {
      right = mergeBorderEdge(right, { colorArgb: parsed });
    }
  }
  const bottomColor = readStyleValue(style, ["borderBottomColor", "border-bottom-color"]);
  if (typeof bottomColor === "string") {
    const parsed = parseCssColorLiteralArgb(bottomColor);
    if (typeof parsed === "number") {
      bottom = mergeBorderEdge(bottom, { colorArgb: parsed });
    }
  }
  const leftColor = readStyleValue(style, ["borderLeftColor", "border-left-color"]);
  if (typeof leftColor === "string") {
    const parsed = parseCssColorLiteralArgb(leftColor);
    if (typeof parsed === "number") {
      left = mergeBorderEdge(left, { colorArgb: parsed });
    }
  }

  if (all == null && top == null && right == null && bottom == null && left == null) {
    return undefined;
  }

  return {
    all,
    top,
    right,
    bottom,
    left,
  };
}

function normalizeIconText(raw: string): string | undefined {
  const value = raw.trim();
  if (value.length === 0) {
    return undefined;
  }
  if (!value.includes("<")) {
    return value;
  }
  let text = "";
  try {
    if (typeof DOMParser !== "undefined") {
      const doc = new DOMParser().parseFromString(value, "text/html");
      text = doc.body.textContent?.trim() ?? "";
    }
  } catch {
    text = "";
  }
  if (text.length === 0) {
    // Fallback for environments without DOMParser.
    text = value.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
  }
  return text.length > 0 ? text : undefined;
}

function resolveAgIconText(iconValue: unknown): string | undefined {
  if (typeof iconValue === "string") {
    return normalizeIconText(iconValue);
  }
  if (typeof iconValue === "function") {
    try {
      const out = iconValue();
      if (typeof out === "string") {
        return normalizeIconText(out);
      }
      if (out instanceof HTMLElement) {
        const text = out.textContent?.trim() ?? "";
        return text.length > 0 ? text : undefined;
      }
    } catch {
      return undefined;
    }
  }
  return undefined;
}

function parseCssPixelLength(raw: string): number | undefined {
  const value = raw.trim();
  if (value.length === 0) {
    return undefined;
  }
  const normalized = value.endsWith("px") ? value.slice(0, -2).trim() : value;
  if (!/^-?\d+(\.\d+)?$/.test(normalized)) {
    return undefined;
  }
  const parsed = Number.parseFloat(normalized);
  if (!Number.isFinite(parsed)) {
    return undefined;
  }
  return Math.max(0, parsed);
}

function parseCssHeightSpec(raw: string, fallbackRatio: number): {
  heightMode: "ratio" | "px";
  heightValue: number;
} {
  const value = raw.trim();
  if (value.endsWith("%")) {
    const parsed = Number.parseFloat(value.slice(0, -1));
    if (Number.isFinite(parsed)) {
      return {
        heightMode: "ratio",
        heightValue: Math.max(0, parsed / 100),
      };
    }
  }
  const px = parseCssPixelLength(value);
  if (typeof px === "number") {
    return {
      heightMode: "px",
      heightValue: px,
    };
  }
  return {
    heightMode: "ratio",
    heightValue: Math.max(0, fallbackRatio),
  };
}

function isCssDisplayEnabled(raw: string): boolean {
  const value = raw.trim().toLowerCase();
  return value.length > 0 && value !== "none" && value !== "0" && value !== "false";
}

function parseRgbFunctionColor(raw: string): number | undefined {
  const match = raw
    .trim()
    .match(/^rgba?\(\s*([0-9.]+)\s*[,\s]\s*([0-9.]+)\s*[,\s]\s*([0-9.]+)(?:\s*[,/]\s*([0-9.]+))?\s*\)$/i);
  if (match == null) {
    return undefined;
  }
  const r = Number.parseFloat(match[1] ?? "");
  const g = Number.parseFloat(match[2] ?? "");
  const b = Number.parseFloat(match[3] ?? "");
  const aRaw = match[4] != null ? Number.parseFloat(match[4]) : 1;
  if (!Number.isFinite(r) || !Number.isFinite(g) || !Number.isFinite(b) || !Number.isFinite(aRaw)) {
    return undefined;
  }
  const rr = Math.max(0, Math.min(255, Math.round(r)));
  const gg = Math.max(0, Math.min(255, Math.round(g)));
  const bb = Math.max(0, Math.min(255, Math.round(b)));
  const aa = Math.max(0, Math.min(255, Math.round(aRaw * 255)));
  return ((aa << 24) | (rr << 16) | (gg << 8) | bb) >>> 0;
}

function resolveCssColorArgb(
  container: HTMLElement,
  rawColor: string,
  fallbackArgb: number,
): number {
  if (rawColor.trim().length === 0) {
    return fallbackArgb >>> 0;
  }
  const probe = document.createElement("div");
  probe.style.position = "absolute";
  probe.style.visibility = "hidden";
  probe.style.pointerEvents = "none";
  probe.style.color = rawColor;
  container.appendChild(probe);
  const computedColor = window.getComputedStyle(probe).color;
  container.removeChild(probe);
  const parsed = parseRgbFunctionColor(computedColor);
  return (parsed ?? fallbackArgb) >>> 0;
}

function resolveHeaderSeparatorSpec(container: HTMLElement): HeaderMarkSpec | null {
  const computed = window.getComputedStyle(container);
  const read = (name: string) => computed.getPropertyValue(name).trim();
  const fallbackColor = resolveCssColorArgb(container, read("--ag-secondary-border-color") || "#c9d2de", 0xffc9d2de);

  const separatorDisplay = read("--ag-header-column-separator-display");
  if (!isCssDisplayEnabled(separatorDisplay)) {
    return null;
  }
  const widthPx = parseCssPixelLength(read("--ag-header-column-separator-width")) ?? 1;
  return {
    colorArgb: resolveCssColorArgb(
      container,
      read("--ag-header-column-separator-color"),
      fallbackColor,
    ),
    widthPx: Math.max(1, Math.round(widthPx)),
    ...parseCssHeightSpec(read("--ag-header-column-separator-height"), 0.5),
  };
}

function resolveHeaderResizeHandleSpec(container: HTMLElement): HeaderMarkSpec | null {
  const computed = window.getComputedStyle(container);
  const read = (name: string) => computed.getPropertyValue(name).trim();
  const fallbackColor = resolveCssColorArgb(container, read("--ag-secondary-border-color") || "#c9d2de", 0xffc9d2de);
  const resizeDisplay = read("--ag-header-column-resize-handle-display");
  if (!isCssDisplayEnabled(resizeDisplay)) {
    return null;
  }
  const widthPx = parseCssPixelLength(read("--ag-header-column-resize-handle-width")) ?? 1;
  return {
    colorArgb: resolveCssColorArgb(
      container,
      read("--ag-header-column-resize-handle-color"),
      fallbackColor,
    ),
    widthPx: Math.max(1, Math.round(widthPx)),
    ...parseCssHeightSpec(read("--ag-header-column-resize-handle-height"), 0.5),
  };
}

export class AgGridVolvox<TData extends RowData = RowData> {
  private readonly container: HTMLElement;
  private readonly canvas: HTMLCanvasElement;
  private readonly wasm: any;
  private readonly grid: VolvoxGrid;
  private cleanupDefaultInput: (() => void) | null = null;
  private readonly eventMapper: VolvoxGridEventMapper<TData>;
  private readonly gridApi: VolvoxGridApi<TData>;

  private options: GridOptions<TData>;
  private columns: NormalizedColDef<TData>[] = [];
  private headerRows = 1;
  private shadowRows: TData[] = [];
  private rowKinds: RowKind[] = [];
  private resizeObserver: ResizeObserver | null = null;
  private destroyed = false;
  private pbErrorLogged = false;

  constructor(params: AgGridVolvoxParams<TData>) {
    this.container = params.container;
    this.wasm = params.wasm;
    this.options = params.gridOptions ?? {};

    this.canvas = document.createElement("canvas");
    this.canvas.style.width = "100%";
    this.canvas.style.height = "100%";
    this.canvas.style.display = "block";

    const currentPosition = window.getComputedStyle(this.container).position;
    if (currentPosition === "static" || currentPosition.length === 0) {
      this.container.style.position = "relative";
    }

    this.container.replaceChildren(this.canvas);

    const initialColumnDefs = this.getEffectiveColumnDefs();
    const initialLayout = normalizeColumnDefs(initialColumnDefs);
    const initialCols = Math.max(1, initialLayout.columns.length);
    this.grid = new VolvoxGrid(this.canvas, this.wasm, 2, initialCols);
    this.cleanupDefaultInput = setupDefaultInput(this.grid as any, this.wasm, this.canvas);
    this.installHeaderStyleHooks();
    this.syncCancelableHooks();

    this.gridApi = new VolvoxGridApi<TData>({
      getGrid: () => this.grid,
      getWasm: () => this.wasm,
      getHeaderRows: () => this.headerRows,
      getColumns: () => this.columns,
      getShadowRows: () => this.shadowRows,
      setRowData: (rows) => {
        this.options = { ...this.options, rowData: rows };
        this.reloadData();
      },
      setColumnDefs: (columnDefs) => {
        this.options = { ...this.options, columnDefs };
        this.reloadData();
      },
      reloadData: () => {
        this.reloadData();
      },
      onColumnMoved: (fromIndex, toIndex) => {
        this.reorderColumnCache(fromIndex, toIndex);
      },
      destroy: () => {
        this.destroy();
      },
    });

    this.eventMapper = new VolvoxGridEventMapper<TData>({
      grid: this.grid,
      getOptions: () => this.options,
      api: this.gridApi,
      getColumns: () => this.columns,
      getShadowRows: () => this.shadowRows,
      getHeaderRows: () => this.headerRows,
    });

    this.reloadData();
    this.installResizeObserver();
    this.eventMapper.start();

    this.options.onGridReady?.({ api: this.gridApi });
  }

  get api(): GridApiLike<TData> {
    return this.gridApi;
  }

  setGridOptions(options: GridOptions<TData>): void {
    this.options = options;
    this.syncCancelableHooks();
    this.reloadData();
  }

  private syncCancelableHooks(): void {
    const beforeEdit = this.options.onBeforeEdit;
    this.grid.onBeforeEdit = beforeEdit == null
      ? null
      : (details: VolvoxGridBeforeEditDetails) => {
          const column = this.columns[details.col];
          if (column == null) {
            return;
          }
          const row = details.row >= 0 ? this.shadowRows[details.row] : undefined;
          const event = {
            api: this.gridApi,
            rowIndex: details.row,
            colIndex: details.col,
            colId: column.field,
            colDef: column.def,
            data: row,
            value: row != null ? row[column.field as keyof TData] : undefined,
            cancel: false,
          };
          beforeEdit(event);
          details.cancel = event.cancel;
        };

    const cellEditValidating = this.options.onCellEditValidating;
    this.grid.onCellEditValidating = cellEditValidating == null
      ? null
      : (details: VolvoxGridCellEditValidatingDetails) => {
          const column = this.columns[details.col];
          if (column == null) {
            return;
          }
          const row = details.row >= 0 ? this.shadowRows[details.row] : undefined;
          const event = {
            api: this.gridApi,
            rowIndex: details.row,
            colIndex: details.col,
            colId: column.field,
            colDef: column.def,
            data: row,
            value: row != null ? row[column.field as keyof TData] : undefined,
            editText: details.editText,
            cancel: false,
          };
          cellEditValidating(event);
          details.cancel = event.cancel;
        };

    const beforeSort = this.options.onBeforeSort;
    this.grid.onBeforeSort = beforeSort == null
      ? null
      : (details: VolvoxGridBeforeSortDetails) => {
          const column = this.columns[details.col];
          if (column == null) {
            return;
          }
          const event = {
            api: this.gridApi,
            colIndex: details.col,
            colId: column.field,
            colDef: column.def,
            cancel: false,
          };
          beforeSort(event);
          details.cancel = event.cancel;
        };
  }

  private getEffectiveColumnDefs(): ColDef<TData>[] {
    const fromOptions = this.options.columnDefs ?? [];
    if (fromOptions.length > 0) {
      return this.applyDefaultColDef(fromOptions);
    }
    return this.applyDefaultColDef(deriveColumnDefs(this.options.rowData ?? []));
  }

  private applyDefaultColDef(columnDefs: ColDef<TData>[]): ColDef<TData>[] {
    const defaults = this.options.defaultColDef;
    if (defaults == null) {
      return columnDefs;
    }

    const apply = (defs: ColDef<TData>[]): ColDef<TData>[] => {
      return defs.map((def) => {
        if (def.children != null && def.children.length > 0) {
          return {
            ...def,
            children: apply(def.children),
          };
        }
        return {
          ...defaults,
          ...def,
        };
      });
    };

    return apply(columnDefs);
  }

  private reloadData(): void {
    if (this.destroyed) {
      return;
    }

    const layout = normalizeColumnDefs(this.getEffectiveColumnDefs());
    this.columns = layout.columns;
    this.headerRows = layout.headerRows;

    const themePreset = applyTheme(
      this.grid,
      this.container,
      this.canvas,
      this.options.theme,
      this.options.fontSize,
    );
    applyGridOptionsToVolvox(
      this.grid,
      this.options,
      this.headerRows,
      this.options.theme,
      themePreset,
    );

    const pinnedTop = this.options.pinnedTopRowData ?? [];
    const body = this.options.rowData ?? [];
    const pinnedBottom = this.options.pinnedBottomRowData ?? [];

    const matrix = mapRowDataToMatrix({
      columns: this.columns,
      rowData: body,
      pinnedTopRowData: pinnedTop,
      pinnedBottomRowData: pinnedBottom,
    });

    this.shadowRows = matrix.shadowRows;
    this.rowKinds = matrix.rowKinds;

    const totalRows = matrix.rows;
    const totalCols = Math.max(1, matrix.cols);
    const values = new Array<string>(totalRows * totalCols).fill("");

    for (let r = 0; r < matrix.rows; r += 1) {
      for (let c = 0; c < matrix.cols; c += 1) {
        const from = r * matrix.cols + c;
        const to = r * totalCols + c;
        values[to] = matrix.values[from];
      }
    }

    this.loadTableValues(totalRows, totalCols, values);
    this.applyColumnHeaderLayout(layout, themePreset.headerHeight);
    this.applyDefaultColumnAlignment();
    this.applyBooleanColumnCheckboxes();
    this.applyCellBorderStyles(matrix.shadowRows, themePreset.cellPadding);
    this.applyIconThemeSlots();

    this.applyPinnedRows();
    this.applyColumnDefinitions();
    this.applyFlexColumns();
    this.applyInitialSorts();
    this.applyHeaderBold();
    this.applyHeaderMarkStyles();
  }

  private loadTableValues(rows: number, cols: number, values: unknown[]): void {
    const rawWasm = this.wasm as {
      volvox_grid_load_table_pb?: (data: Uint8Array) => Uint8Array;
      volvox_grid_last_error?: () => string;
    };
    if (typeof rawWasm.volvox_grid_load_table_pb === "function") {
      const request = encodeLoadTableRequest({
        gridId: this.grid.id,
        rows,
        cols,
        values,
      });
      rawWasm.volvox_grid_load_table_pb(request);
      this.logPbError(rawWasm, "table load");
      return;
    }

    this.grid.rowCount = rows;
    this.grid.colCount = cols;
    const safeCols = Math.max(1, cols);
    for (let i = 0; i < values.length; i += 1) {
      const row = Math.floor(i / safeCols);
      const col = i % safeCols;
      const value = values[i];
      this.grid.setCellText(row, col, value == null ? "" : String(value));
    }
  }

  private evaluateRawValue(
    row: TData,
    column: NormalizedColDef<TData>,
    rowIndex: number,
  ): unknown {
    if (typeof column.def.valueGetter === "function") {
      return column.def.valueGetter({
        data: row,
        field: column.def.field,
        colDef: column.def,
        rowIndex,
      });
    }
    return row[column.field as keyof TData];
  }

  private applyBooleanColumnCheckboxes(): void {
    const rawWasm = this.wasm as {
      volvox_grid_define_columns_pb?: (data: Uint8Array) => Uint8Array;
      volvox_grid_update_cells_pb?: (data: Uint8Array) => Uint8Array;
      volvox_grid_last_error?: () => string;
    };
    if (
      typeof rawWasm.volvox_grid_define_columns_pb !== "function"
      || typeof rawWasm.volvox_grid_update_cells_pb !== "function"
    ) {
      return;
    }

    const booleanColumns: number[] = [];
    for (const col of this.columns) {
      let foundBoolean = false;
      for (let rowIndex = 0; rowIndex < this.shadowRows.length; rowIndex += 1) {
        const raw = this.evaluateRawValue(this.shadowRows[rowIndex], col, rowIndex);
        if (typeof raw === "boolean") {
          foundBoolean = true;
          break;
        }
      }
      if (foundBoolean) {
        booleanColumns.push(col.index);
      }
    }

    if (booleanColumns.length === 0) {
      return;
    }

    const defineReq = encodeDefineBooleanColumnsRequest({
      gridId: this.grid.id,
      columnIndices: booleanColumns,
    });
    rawWasm.volvox_grid_define_columns_pb(defineReq);
    this.logPbError(rawWasm, "boolean column definition");

    const checkedUpdates: Array<{ row: number; col: number; checked: number }> = [];
    for (let rowIndex = 0; rowIndex < this.shadowRows.length; rowIndex += 1) {
      const row = this.shadowRows[rowIndex];
      for (const colIndex of booleanColumns) {
        const col = this.columns[colIndex];
        if (col == null) {
          continue;
        }
        const raw = this.evaluateRawValue(row, col, rowIndex);
        if (typeof raw !== "boolean") {
          continue;
        }
        checkedUpdates.push({
          row: rowIndex,
          col: col.index,
          checked: raw ? CheckedState.CHECKED_CHECKED : CheckedState.CHECKED_UNCHECKED,
        });
      }
    }

    if (checkedUpdates.length > 0) {
      const updateReq = encodeUpdateCheckedCellsRequest({
        gridId: this.grid.id,
        updates: checkedUpdates,
      });
      rawWasm.volvox_grid_update_cells_pb(updateReq);
      this.logPbError(rawWasm, "boolean checked-state update");
    }
  }

  private applyDefaultColumnAlignment(): void {
    if (this.columns.length === 0) {
      return;
    }

    const rawWasm = this.wasm as {
      volvox_grid_define_columns_pb?: (data: Uint8Array) => Uint8Array;
      volvox_grid_last_error?: () => string;
    };
    if (typeof rawWasm.volvox_grid_define_columns_pb !== "function") {
      return;
    }

    const req = encodeDefineColumnAlignmentsRequest({
      gridId: this.grid.id,
      columnIndices: this.columns.map((c) => c.index),
      alignment: Align.ALIGN_LEFT_CENTER,
      fixedAlignment: Align.ALIGN_LEFT_CENTER,
    });
    rawWasm.volvox_grid_define_columns_pb(req);
    this.logPbError(rawWasm, "column alignment update");
  }

  private applyHeaderBold(): void {
    // Indicator-band headers are no longer represented as grid cells, so the
    // old cell-space bold override path does not apply here.
  }

  private installHeaderStyleHooks(): void {
    const gridWithMutableMethods = this.grid as unknown as {
      setFontName?: (name: string) => void;
      setFontSize?: (size: number) => void;
    };

    if (typeof gridWithMutableMethods.setFontName === "function") {
      const originalSetFontName = gridWithMutableMethods.setFontName.bind(this.grid);
      gridWithMutableMethods.setFontName = (name: string) => {
        originalSetFontName(name);
        this.applyHeaderBold();
      };
    }

    if (typeof gridWithMutableMethods.setFontSize === "function") {
      const originalSetFontSize = gridWithMutableMethods.setFontSize.bind(this.grid);
      gridWithMutableMethods.setFontSize = (size: number) => {
        originalSetFontSize(size);
        this.applyHeaderBold();
      };
    }
  }

  private applyCellBorderStyles(rows: TData[], fallbackPadding: PaddingPreset): void {
    if (rows.length === 0 || this.columns.length === 0) {
      return;
    }
    const rawWasm = this.wasm as {
      volvox_grid_update_cells_pb?: (data: Uint8Array) => Uint8Array;
      volvox_grid_last_error?: () => string;
    };
    if (typeof rawWasm.volvox_grid_update_cells_pb !== "function") {
      return;
    }

    const styleMatrix = mapCellStyles({
      columns: this.columns,
      rowData: rows,
    });
    if (styleMatrix.cells.length === 0) {
      return;
    }

    const updates: CellBorderUpdate[] = [];
    for (const cell of styleMatrix.cells) {
      const col = this.columns[cell.colIndex];
      if (col == null) {
        continue;
      }
      const border = resolveBorderFromCellStyle(cell.style);
      const padding = resolvePaddingFromCellStyle(cell.style, fallbackPadding);
      if (border == null && padding == null) {
        continue;
      }
      updates.push({
        row: cell.rowIndex,
        col: col.index,
        left: padding?.left,
        top: padding?.top,
        right: padding?.right,
        bottom: padding?.bottom,
        border: border?.all?.style,
        borderColor: border?.all?.colorArgb,
        borderTop: border?.top?.style,
        borderRight: border?.right?.style,
        borderBottom: border?.bottom?.style,
        borderLeft: border?.left?.style,
        borderTopColor: border?.top?.colorArgb,
        borderRightColor: border?.right?.colorArgb,
        borderBottomColor: border?.bottom?.colorArgb,
        borderLeftColor: border?.left?.colorArgb,
      });
    }

    if (updates.length === 0) {
      return;
    }
    const req = encodeUpdateCellBordersRequest({
      gridId: this.grid.id,
      updates,
    });
    rawWasm.volvox_grid_update_cells_pb(req);
    this.logPbError(rawWasm, "cell border style update");
  }

  private applyIconThemeSlots(): void {
    const icons = this.options.icons ?? {};
    const slots: Record<string, { source: { kind: "none" } | { kind: "text"; text: string } }> = {};
    for (const mapping of AG_TO_VV_ICON_SLOT) {
      const text = resolveAgIconText(icons[mapping.agKey]);
      slots[mapping.vvKey] = text == null
        ? { source: { kind: "none" } }
        : { source: { kind: "text", text } };
    }
    if (typeof this.grid.setIconTheme === "function") {
      this.grid.setIconTheme({ slots });
      return;
    }
    if (typeof this.grid.setIconSlots === "function") {
      const legacySlots: Record<string, string> = {};
      for (const mapping of AG_TO_VV_ICON_SLOT) {
        const text = resolveAgIconText(icons[mapping.agKey]);
        legacySlots[mapping.vvKey] = text ?? "";
      }
      this.grid.setIconSlots(legacySlots);
      return;
    }
    if (typeof this.grid.setIconThemeSlots === "function") {
      const legacySlots: Record<string, string> = {};
      for (const mapping of AG_TO_VV_ICON_SLOT) {
        const text = resolveAgIconText(icons[mapping.agKey]);
        legacySlots[mapping.vvKey] = text ?? "";
      }
      this.grid.setIconThemeSlots(legacySlots);
    }
  }

  private logPbError(
    wasm: { volvox_grid_last_error?: () => string },
    context: string,
  ): void {
    if (typeof wasm.volvox_grid_last_error !== "function") {
      return;
    }
    const err = wasm.volvox_grid_last_error();
    if (!this.pbErrorLogged && err.trim().length > 0) {
      this.pbErrorLogged = true;
      console.warn(`[aggrid-adapter] failed ${context}: ${err}`);
    }
  }

  private applyPinnedRows(): void {
    for (let i = 0; i < this.rowKinds.length; i += 1) {
      const row = i;
      const kind = this.rowKinds[i];
      if (kind === "pinnedTop") {
        this.grid.pinRow(row, VolvoxGrid.PIN_TOP);
      } else if (kind === "pinnedBottom") {
        this.grid.pinRow(row, VolvoxGrid.PIN_BOTTOM);
      } else {
        this.grid.pinRow(row, VolvoxGrid.PIN_NONE);
      }
    }
  }

  private applyColumnDefinitions(): void {
    for (const col of this.columns) {
      const def = col.def;

      const preferredWidth = def.hide
        ? 0
        : clampColumnWidth(def.width ?? DEFAULT_COLUMN_WIDTH, def.minWidth, def.maxWidth);
      this.grid.setColWidth(col.index, preferredWidth);

      if (typeof this.grid.pinCol === "function") {
        if (def.pinned === "left") {
          this.grid.pinCol(col.index, VolvoxGrid.PIN_COL_LEFT);
        } else if (def.pinned === "right") {
          this.grid.pinCol(col.index, VolvoxGrid.PIN_COL_RIGHT);
        } else {
          this.grid.pinCol(col.index, VolvoxGrid.PIN_COL_NONE);
        }
        this.grid.setColSticky(col.index, VolvoxGrid.STICKY_NONE);
      } else if (def.pinned === "left") {
        this.grid.setColSticky(col.index, VolvoxGrid.STICKY_LEFT);
      } else if (def.pinned === "right") {
        this.grid.setColSticky(col.index, VolvoxGrid.STICKY_RIGHT);
      } else {
        this.grid.setColSticky(col.index, VolvoxGrid.STICKY_NONE);
      }
    }
  }

  private applyFlexColumns(): void {
    if (this.columns.length === 0) {
      return;
    }

    const visibleWidth = Math.max(0, this.container.clientWidth);
    if (visibleWidth <= 0) {
      return;
    }

    let fixedWidth = 0;
    let flexTotal = 0;

    for (const col of this.columns) {
      if (col.def.hide) {
        continue;
      }
      if (typeof col.def.flex === "number" && col.def.flex > 0) {
        flexTotal += col.def.flex;
      } else {
        const w = col.def.width ?? DEFAULT_COLUMN_WIDTH;
        fixedWidth += clampColumnWidth(w, col.def.minWidth, col.def.maxWidth);
      }
    }

    if (flexTotal <= 0) {
      return;
    }

    const flexSpace = Math.max(0, visibleWidth - fixedWidth);
    for (const col of this.columns) {
      if (col.def.hide) {
        continue;
      }
      const flex = col.def.flex;
      if (typeof flex !== "number" || flex <= 0) {
        continue;
      }
      const ratio = flex / flexTotal;
      const rawWidth = Math.max(24, Math.floor(flexSpace * ratio));
      const finalWidth = clampColumnWidth(rawWidth, col.def.minWidth, col.def.maxWidth);
      this.grid.setColWidth(col.index, finalWidth);
    }
  }

  private applyInitialSorts(): void {
    const cols: number[] = [];
    const orders: number[] = [];
    for (const col of this.columns) {
      if (col.def.sort === "asc") {
        cols.push(col.index);
        orders.push(SortOrder.SORT_ASCENDING);
      } else if (col.def.sort === "desc") {
        cols.push(col.index);
        orders.push(SortOrder.SORT_DESCENDING);
      }
    }
    if (cols.length > 0) {
      this.grid.sortMulti(cols, orders);
    }
  }

  private reorderColumnCache(fromIndex: number, toIndex: number): void {
    const from = Math.max(0, Math.min(this.columns.length - 1, Math.trunc(fromIndex)));
    const to = Math.max(0, Math.min(this.columns.length - 1, Math.trunc(toIndex)));
    if (from === to || this.columns.length <= 1) {
      return;
    }
    const [col] = this.columns.splice(from, 1);
    if (col == null) {
      return;
    }
    this.columns.splice(to, 0, col);
  }

  private applyHeaderMarkStyles(): void {
    const separator = resolveHeaderSeparatorSpec(this.container);
    const resizeHandle = resolveHeaderResizeHandleSpec(this.container);
    const visualSpec = separator ?? resizeHandle;
    const setHeaderSeparator = typeof this.grid.setHeaderSeparator === "function"
      ? this.grid.setHeaderSeparator.bind(this.grid)
      : this.grid.setHeaderSeparatorStyle.bind(this.grid);
    const setHeaderResizeHandle = typeof this.grid.setHeaderResizeHandle === "function"
      ? this.grid.setHeaderResizeHandle.bind(this.grid)
      : this.grid.setHeaderResizeHandleStyle.bind(this.grid);
    if (visualSpec != null) {
      setHeaderSeparator({
        enabled: true,
        colorArgb: visualSpec.colorArgb,
        widthPx: visualSpec.widthPx,
        height: {
          mode: visualSpec.heightMode,
          value: visualSpec.heightValue,
        },
        skipMerged: true,
      });
    } else {
      setHeaderSeparator({
        enabled: false,
      });
    }

    setHeaderResizeHandle({
      // Keep resize-handle style for interaction hitbox only.
      enabled: false,
      hitWidthPx: resizeHandle != null ? Math.max(6, resizeHandle.widthPx) : 6,
      showOnlyWhenResizable: true,
    });
  }

  private applyColumnHeaderLayout(
    layout: ColumnLayout<TData>,
    defaultHeaderHeight: number,
  ): void {
    for (const col of this.columns) {
      this.grid.setColumnCaption(col.index, layout.leafHeaderTexts[col.index] ?? "");
    }

    const cells = this.buildColumnIndicatorCells(layout);
    applyColumnIndicatorTopConfig(this.grid, {
      visible: this.headerRows > 0,
      rowCount: this.headerRows,
      defaultRowHeight: defaultHeaderHeight,
      cells,
    });
  }

  private buildColumnIndicatorCells(
    layout: ColumnLayout<TData>,
  ): ColumnIndicatorCellConfig[] {
    if (this.headerRows <= 1 || !layout.hasColumnGroups) {
      return this.columns.map((col) => ({
        row1: 0,
        row2: 0,
        col1: col.index,
        col2: col.index,
        text: layout.leafHeaderTexts[col.index] ?? "",
      }));
    }

    const cells: ColumnIndicatorCellConfig[] = [];
    let groupStart = -1;
    let groupLabel = "";

    const flushGroup = (groupEnd: number): void => {
      if (groupStart < 0 || groupLabel.length === 0 || groupEnd < groupStart) {
        return;
      }
      cells.push({
        row1: 0,
        row2: 0,
        col1: groupStart,
        col2: groupEnd,
        text: groupLabel,
      });
    };

    for (const col of this.columns) {
      const leafText = layout.leafHeaderTexts[col.index] ?? "";
      const parent = col.parentHeader?.trim() ?? "";
      if (parent.length === 0) {
        flushGroup(col.index - 1);
        groupStart = -1;
        groupLabel = "";
        cells.push({
          row1: 0,
          row2: 1,
          col1: col.index,
          col2: col.index,
          text: leafText,
        });
        continue;
      }

      if (groupStart < 0) {
        groupStart = col.index;
        groupLabel = parent;
      } else if (groupLabel !== parent) {
        flushGroup(col.index - 1);
        groupStart = col.index;
        groupLabel = parent;
      }

      cells.push({
        row1: 1,
        row2: 1,
        col1: col.index,
        col2: col.index,
        text: leafText,
      });
    }

    flushGroup(this.columns.length - 1);
    return cells;
  }

  private installResizeObserver(): void {
    if (typeof ResizeObserver === "undefined") {
      return;
    }
    this.resizeObserver = new ResizeObserver(() => {
      this.applyFlexColumns();
    });
    this.resizeObserver.observe(this.container);
  }

  destroy(): void {
    if (this.destroyed) {
      return;
    }
    this.destroyed = true;
    this.eventMapper.stop();
    this.resizeObserver?.disconnect();
    this.resizeObserver = null;
    this.cleanupDefaultInput?.();
    this.grid.destroy();
    this.container.replaceChildren();
  }
}
