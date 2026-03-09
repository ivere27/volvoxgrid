import type { VolvoxGrid } from "volvoxgrid";
import type { ColDef, GridOptions, RowData } from "./types.js";
import { resolveTheme, type ThemePreset } from "./theme-mapper.js";

const SELECTION_FREE = 0;
const SELECTION_BY_ROW = 1;
const HIGHLIGHT_NEVER = 0;
const HIGHLIGHT_WITH_FOCUS = 2;
const CELL_SPAN_NONE = 0;
const CELL_SPAN_HEADER_ONLY = 5;
const COLOR_WHITE_ARGB = 0xffffffff;
let v1PluginInitAttempted = false;
let configureErrorLogged = false;

type ConfigureWasm = {
  init_v1_plugin?: () => void;
  volvox_grid_configure?: (gridId: bigint, config: Uint8Array) => Uint8Array;
  volvox_grid_last_error?: () => string;
};

type CellPaddingConfig = {
  left: number;
  top: number;
  right: number;
  bottom: number;
};

export type ColumnIndicatorCellConfig = {
  row1: number;
  row2: number;
  col1: number;
  col2: number;
  text: string;
};

function encodeVarintUnsigned(value: bigint): number[] {
  const out: number[] = [];
  let v = BigInt.asUintN(64, value);
  while (v >= 0x80n) {
    out.push(Number((v & 0x7fn) | 0x80n));
    v >>= 7n;
  }
  out.push(Number(v));
  return out;
}

function encodeTag(field: number, wireType: number): number[] {
  return encodeVarintUnsigned(BigInt((field << 3) | wireType));
}

function encodeInt32(value: number): number[] {
  const i32 = BigInt.asIntN(32, BigInt(Math.trunc(value)));
  return encodeVarintUnsigned(BigInt.asUintN(64, i32));
}

function encodeBool(value: boolean): number[] {
  return encodeVarintUnsigned(value ? 1n : 0n);
}

function encodeStringField(field: number, value: string): number[] {
  const bytes = Array.from(new TextEncoder().encode(value));
  return [
    ...encodeTag(field, 2),
    ...encodeVarintUnsigned(BigInt(bytes.length)),
    ...bytes,
  ];
}

function clampPadding(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.round(value));
}

function encodeCellPaddingMessage(padding: CellPaddingConfig): number[] {
  const out: number[] = [];
  out.push(...encodeTag(1, 0), ...encodeInt32(clampPadding(padding.left)));
  out.push(...encodeTag(2, 0), ...encodeInt32(clampPadding(padding.top)));
  out.push(...encodeTag(3, 0), ...encodeInt32(clampPadding(padding.right)));
  out.push(...encodeTag(4, 0), ...encodeInt32(clampPadding(padding.bottom)));
  return out;
}

function encodeStyleBackColorFixedConfig(colorArgb: number): Uint8Array {
  // GridConfig.style (field=2) => StyleConfig.fixed (field=11)
  // => RegionStyle.background (field=1)
  const fixedPayload: number[] = [];
  fixedPayload.push(...encodeTag(1, 0), ...encodeVarintUnsigned(BigInt(colorArgb >>> 0)));

  const stylePayload: number[] = [];
  stylePayload.push(
    ...encodeTag(11, 2),
    ...encodeVarintUnsigned(BigInt(fixedPayload.length)),
    ...fixedPayload,
  );

  const configPayload: number[] = [];
  configPayload.push(
    ...encodeTag(2, 2),
    ...encodeVarintUnsigned(BigInt(stylePayload.length)),
    ...stylePayload,
  );
  return new Uint8Array(configPayload);
}

function encodeStylePaddingConfig(args: {
  cellPadding: CellPaddingConfig;
  fixedCellPadding: CellPaddingConfig;
}): Uint8Array {
  // GridConfig.style (field=2)
  // StyleConfig.cell_padding = 5
  // StyleConfig.fixed = 11 => RegionStyle.cell_padding = 7
  const stylePayload: number[] = [];

  const cellPadding = encodeCellPaddingMessage(args.cellPadding);
  stylePayload.push(
    ...encodeTag(5, 2),
    ...encodeVarintUnsigned(BigInt(cellPadding.length)),
    ...cellPadding,
  );

  const fixedCellPadding = encodeCellPaddingMessage(args.fixedCellPadding);
  const fixedRegionPayload: number[] = [];
  fixedRegionPayload.push(
    ...encodeTag(7, 2),
    ...encodeVarintUnsigned(BigInt(fixedCellPadding.length)),
    ...fixedCellPadding,
  );
  stylePayload.push(
    ...encodeTag(11, 2),
    ...encodeVarintUnsigned(BigInt(fixedRegionPayload.length)),
    ...fixedRegionPayload,
  );

  const configPayload: number[] = [];
  configPayload.push(
    ...encodeTag(2, 2),
    ...encodeVarintUnsigned(BigInt(stylePayload.length)),
    ...stylePayload,
  );
  return new Uint8Array(configPayload);
}

function encodeSpanFixedModeConfig(mode: number): Uint8Array {
  // GridConfig.span (field=7) => SpanConfig.cell_span_fixed (field=2)
  const spanPayload: number[] = [];
  spanPayload.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(Math.trunc(mode))));

  const configPayload: number[] = [];
  configPayload.push(...encodeTag(7, 2), ...encodeVarintUnsigned(BigInt(spanPayload.length)), ...spanPayload);
  return new Uint8Array(configPayload);
}

function encodeColIndicatorTopConfig(args: {
  visible: boolean;
  rowCount: number;
  defaultRowHeight: number;
  cells: ColumnIndicatorCellConfig[];
}): Uint8Array {
  const colTopPayload: number[] = [];
  colTopPayload.push(...encodeTag(1, 0), ...encodeBool(args.visible));
  colTopPayload.push(
    ...encodeTag(2, 0),
    ...encodeInt32(Math.max(1, Math.round(args.defaultRowHeight))),
  );
  colTopPayload.push(
    ...encodeTag(3, 0),
    ...encodeInt32(Math.max(0, Math.trunc(args.rowCount))),
  );

  for (const cell of args.cells) {
    const cellPayload: number[] = [];
    cellPayload.push(...encodeTag(1, 0), ...encodeInt32(cell.row1));
    cellPayload.push(...encodeTag(2, 0), ...encodeInt32(cell.row2));
    cellPayload.push(...encodeTag(3, 0), ...encodeInt32(cell.col1));
    cellPayload.push(...encodeTag(4, 0), ...encodeInt32(cell.col2));
    cellPayload.push(...encodeStringField(5, cell.text));
    colTopPayload.push(
      ...encodeTag(14, 2),
      ...encodeVarintUnsigned(BigInt(cellPayload.length)),
      ...cellPayload,
    );
  }

  const indicatorBandsPayload: number[] = [];
  indicatorBandsPayload.push(
    ...encodeTag(3, 2),
    ...encodeVarintUnsigned(BigInt(colTopPayload.length)),
    ...colTopPayload,
  );

  const gridConfig: number[] = [];
  gridConfig.push(
    ...encodeTag(11, 2),
    ...encodeVarintUnsigned(BigInt(indicatorBandsPayload.length)),
    ...indicatorBandsPayload,
  );
  return new Uint8Array(gridConfig);
}

function ensureV1PluginInitialized(wasm: unknown): void {
  if (v1PluginInitAttempted) {
    return;
  }
  v1PluginInitAttempted = true;
  const module = wasm as { init_v1_plugin?: () => void };
  if (typeof module.init_v1_plugin !== "function") {
    return;
  }
  try {
    module.init_v1_plugin();
  } catch {
    // Non-fatal: direct APIs still work even if plugin init fails.
  }
}

function getConfigureTarget(grid: VolvoxGrid): { gridId: bigint; wasm: ConfigureWasm } | null {
  const internal = grid as unknown as { id?: number; wasm?: unknown };
  const gridId = internal.id;
  const wasm = internal.wasm as ConfigureWasm | undefined;
  ensureV1PluginInitialized(wasm);
  if (typeof gridId !== "number" || !Number.isFinite(gridId)) {
    return null;
  }
  if (typeof wasm?.volvox_grid_configure !== "function") {
    return null;
  }
  return {
    gridId: BigInt(Math.trunc(gridId)),
    wasm,
  };
}

function applyGridConfig(grid: VolvoxGrid, config: Uint8Array, purpose: string): void {
  const target = getConfigureTarget(grid);
  if (target == null) {
    return;
  }
  target.wasm.volvox_grid_configure?.(target.gridId, config);
  if (typeof target.wasm.volvox_grid_last_error === "function") {
    const err = target.wasm.volvox_grid_last_error();
    if (!configureErrorLogged && err.trim().length > 0) {
      configureErrorLogged = true;
      console.warn(`[aggrid-adapter] failed to apply ${purpose}: ${err}`);
    }
  }
}

function applyHeaderBackgroundWhite(grid: VolvoxGrid): void {
  applyGridConfig(grid, encodeStyleBackColorFixedConfig(COLOR_WHITE_ARGB), "header style config");
}

function applyThemePadding(grid: VolvoxGrid, args: {
  cellPadding: CellPaddingConfig;
  fixedCellPadding: CellPaddingConfig;
}): void {
  applyGridConfig(grid, encodeStylePaddingConfig(args), "theme padding config");
}

function applyFixedHeaderSpanMode(grid: VolvoxGrid, enabled: boolean): void {
  const mode = enabled ? CELL_SPAN_HEADER_ONLY : CELL_SPAN_NONE;
  applyGridConfig(grid, encodeSpanFixedModeConfig(mode), "fixed header span config");
}

export function applyColumnIndicatorTopConfig(grid: VolvoxGrid, args: {
  visible: boolean;
  rowCount: number;
  defaultRowHeight: number;
  cells: ColumnIndicatorCellConfig[];
}): void {
  applyGridConfig(
    grid,
    encodeColIndicatorTopConfig(args),
    "column indicator top config",
  );
}

function hasColumnGroups<TData extends RowData>(columnDefs: ColDef<TData>[]): boolean {
  return columnDefs.some((c) => c.children != null && c.children.length > 0);
}

function resolveLeafBooleanFlag<TData extends RowData>(
  colDef: ColDef<TData>,
  defaultColDef: Partial<ColDef<TData>> | undefined,
  key: "sortable" | "resizable",
): boolean {
  const own = colDef[key];
  if (typeof own === "boolean") {
    return own;
  }
  const inherited = defaultColDef?.[key];
  return inherited === true;
}

function hasAnySortable<TData extends RowData>(
  columnDefs: ColDef<TData>[],
  defaultColDef?: Partial<ColDef<TData>>,
): boolean {
  return columnDefs.some((c) =>
    c.children != null && c.children.length > 0
      ? hasAnySortable(c.children, defaultColDef)
      : resolveLeafBooleanFlag(c, defaultColDef, "sortable"));
}

function hasAnyResizable<TData extends RowData>(
  columnDefs: ColDef<TData>[],
  defaultColDef?: Partial<ColDef<TData>>,
): boolean {
  return columnDefs.some((c) =>
    c.children != null && c.children.length > 0
      ? hasAnyResizable(c.children, defaultColDef)
      : resolveLeafBooleanFlag(c, defaultColDef, "resizable"));
}

function hasAnyReorder<TData extends RowData>(_columnDefs: ColDef<TData>[]): boolean {
  return true;
}

export function applyGridOptionsToVolvox<TData extends RowData>(
  grid: VolvoxGrid,
  gridOptions: GridOptions<TData>,
  headerRows: number,
  theme?: GridOptions<TData>["theme"],
  resolvedThemePreset?: ThemePreset,
): void {
  const themePreset = resolvedThemePreset ?? resolveTheme(theme);

  const colDefs = gridOptions.columnDefs ?? [];
  const sortable = hasAnySortable(colDefs, gridOptions.defaultColDef);
  const reorder = hasAnyReorder(colDefs);
  grid.setHeaderFeatures({ sort: sortable, reorder, chooser: false });

  const rowSelectionEnabled =
    gridOptions.rowSelection === "single" || gridOptions.rowSelection === "multiple";
  grid.selectionMode = rowSelectionEnabled ? SELECTION_BY_ROW : SELECTION_FREE;
  grid.selectionVisibility = rowSelectionEnabled ? HIGHLIGHT_WITH_FOCUS : HIGHLIGHT_NEVER;
  grid.focusBorder = 0;

  const resizable = hasAnyResizable(colDefs, gridOptions.defaultColDef);
  grid.setResizePolicy({ columns: resizable, rows: resizable, uniform: false });

  const rowHeight =
    typeof gridOptions.rowHeight === "number" && gridOptions.rowHeight > 0
      ? Math.round(gridOptions.rowHeight)
      : themePreset.rowHeight;
  grid.defaultRowHeight = rowHeight;

  const headerHeight =
    typeof gridOptions.headerHeight === "number" && gridOptions.headerHeight > 0
      ? Math.round(gridOptions.headerHeight)
      : themePreset.headerHeight;
  applyHeaderBackgroundWhite(grid);
  applyThemePadding(grid, {
    cellPadding: themePreset.cellPadding,
    fixedCellPadding: themePreset.fixedCellPadding,
  });

  grid.animationEnabled = gridOptions.animateRows === true;

  grid.showColumnHeaders = headerRows > 0;
  grid.columnIndicatorTopRowCount = Math.max(0, headerRows);
  grid.cellSpanMode = CELL_SPAN_NONE;
  applyFixedHeaderSpanMode(grid, false);
}
