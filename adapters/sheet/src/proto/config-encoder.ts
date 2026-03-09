/**
 * Encode GridConfig (ConfigureRequest) for VolvoxGrid WASM.
 *
 * ConfigureRequest { grid_id=1, config=2 { GridConfig } }
 * GridConfig { layout=1, style=2, selection=3, editing=4, ... }
 */

import {
  encodeTag, encodeInt32, encodeBool,
  encodeVarintUnsigned, encodeMessageField, encodeStringField,
  encodeHighlightStyle, encodeFont, encodeBorders,
  type HighlightStyleArg, type FontArg, type BordersArg,
} from "./proto-utils.js";

// ── GridLines helper ────────────────────────────────────────
// GridLines { style=1, direction=2, color=3, width=4 }

export interface GridLinesArg {
  style?: number;       // GridLineStyle enum
  direction?: number;   // GridLineDirection enum
  color?: number;       // ARGB uint32
  width?: number;       // pixel width
}

function encodeGridLines(gl: GridLinesArg): number[] {
  const out: number[] = [];
  if (gl.style != null) out.push(...encodeTag(1, 0), ...encodeInt32(gl.style));
  if (gl.direction != null) out.push(...encodeTag(2, 0), ...encodeInt32(gl.direction));
  if (gl.color != null) {
    out.push(...encodeTag(3, 0), ...encodeVarintUnsigned(BigInt(gl.color >>> 0)));
  }
  if (gl.width != null) out.push(...encodeTag(4, 0), ...encodeInt32(gl.width));
  return out;
}

// ── RegionStyle helper ──────────────────────────────────────
// RegionStyle { background=1, foreground=2, font=3, grid_lines=4,
//               text_effect=5, separator=6, cell_padding=7 }

export interface RegionStyleArg {
  background?: number;
  foreground?: number;
  font?: FontArg;
  gridLines?: GridLinesArg;
  textEffect?: number;
}

function encodeRegionStyle(rs: RegionStyleArg): number[] {
  const out: number[] = [];
  if (rs.background != null) {
    out.push(...encodeTag(1, 0), ...encodeVarintUnsigned(BigInt(rs.background >>> 0)));
  }
  if (rs.foreground != null) {
    out.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(rs.foreground >>> 0)));
  }
  if (rs.font) {
    const f = encodeFont(rs.font);
    if (f.length > 0) out.push(...encodeMessageField(3, f));
  }
  if (rs.gridLines) {
    const gl = encodeGridLines(rs.gridLines);
    if (gl.length > 0) out.push(...encodeMessageField(4, gl));
  }
  if (rs.textEffect != null) out.push(...encodeTag(5, 0), ...encodeInt32(rs.textEffect));
  return out;
}

// ── HoverConfig helper ──────────────────────────────────────
// HoverConfig { row=1, column=2, cell=3, row_style=4, column_style=5, cell_style=6 }

export interface HoverConfigArg {
  row?: boolean;
  column?: boolean;
  cell?: boolean;
  rowStyle?: HighlightStyleArg;
  columnStyle?: HighlightStyleArg;
  cellStyle?: HighlightStyleArg;
}

function encodeHoverConfig(hover: HoverConfigArg): number[] {
  const out: number[] = [];
  if (hover.row != null) out.push(...encodeTag(1, 0), ...encodeBool(hover.row));
  if (hover.column != null) out.push(...encodeTag(2, 0), ...encodeBool(hover.column));
  if (hover.cell != null) out.push(...encodeTag(3, 0), ...encodeBool(hover.cell));
  if (hover.rowStyle) {
    out.push(...encodeMessageField(4, encodeHighlightStyle(hover.rowStyle)));
  }
  if (hover.columnStyle) {
    out.push(...encodeMessageField(5, encodeHighlightStyle(hover.columnStyle)));
  }
  if (hover.cellStyle) {
    out.push(...encodeMessageField(6, encodeHighlightStyle(hover.cellStyle)));
  }
  return out;
}

// ── ResizePolicy helper ─────────────────────────────────────
// ResizePolicy { columns=1, rows=2, uniform=3 }

export interface ResizePolicyArg {
  columns?: boolean;
  rows?: boolean;
  uniform?: boolean;
}

function encodeResizePolicy(rp: ResizePolicyArg): number[] {
  const out: number[] = [];
  if (rp.columns != null) out.push(...encodeTag(1, 0), ...encodeBool(rp.columns));
  if (rp.rows != null) out.push(...encodeTag(2, 0), ...encodeBool(rp.rows));
  if (rp.uniform != null) out.push(...encodeTag(3, 0), ...encodeBool(rp.uniform));
  return out;
}

// ── Main config interface ───────────────────────────────────

export interface SheetGridConfig {
  // LayoutConfig
  rows?: number;
  cols?: number;
  frozenRows?: number;
  frozenCols?: number;
  defaultRowHeight?: number;
  defaultColWidth?: number;

  // StyleConfig
  background?: number;
  foreground?: number;
  alternateBackground?: number;
  font?: FontArg;
  gridLines?: GridLinesArg;
  fixed?: RegionStyleArg;
  textOverflow?: boolean;

  // SelectionConfig
  selectionMode?: number;
  focusBorder?: number;
  selectionStyle?: HighlightStyleArg;
  hover?: HoverConfigArg;
  indicatorRowStyle?: HighlightStyleArg;
  indicatorColStyle?: HighlightStyleArg;

  // EditConfig
  editTrigger?: number;
  tabBehavior?: number;
  hostKeyDispatch?: boolean;

  // InteractionConfig
  resize?: ResizePolicyArg;
  autoResize?: boolean;

  // SpanConfig
  cellSpan?: number;
  cellSpanFixed?: number;

  // IndicatorsConfig
  indicators?: {
    rowStart?: {
      visible?: boolean;
      width?: number;
      modeBits?: number;
      background?: number;
      foreground?: number;
      gridLines?: number;    // GridLineStyle enum (not GridLines msg)
      gridColor?: number;
      allowResize?: boolean;
    };
    colTop?: {
      visible?: boolean;
      defaultRowHeight?: number;
      bandRows?: number;
      modeBits?: number;
      background?: number;
      foreground?: number;
      gridLines?: number;    // GridLineStyle enum
      gridColor?: number;
      allowResize?: boolean;
    };
    cornerTopStart?: {
      visible?: boolean;
      modeBits?: number;
      background?: number;
      foreground?: number;
    };
  };
}

// ── Indicator encoders ──────────────────────────────────────
// RowIndicatorConfig { visible=1, width=2, mode_bits=3, background=4,
//   foreground=5, grid_lines=6, grid_color=7, auto_size=8,
//   allow_resize=9, allow_select=10, allow_reorder=11, slots=12 }

function encodeRowIndicatorConfig(config: NonNullable<SheetGridConfig["indicators"]>["rowStart"]): number[] {
  const out: number[] = [];
  if (!config) return out;
  if (config.visible != null) out.push(...encodeTag(1, 0), ...encodeBool(config.visible));
  if (config.width != null) out.push(...encodeTag(2, 0), ...encodeInt32(config.width));
  if (config.modeBits != null) {
    out.push(...encodeTag(3, 0), ...encodeVarintUnsigned(BigInt(config.modeBits >>> 0)));
  }
  if (config.background != null) {
    out.push(...encodeTag(4, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    out.push(...encodeTag(5, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  if (config.gridLines != null) out.push(...encodeTag(6, 0), ...encodeInt32(config.gridLines));
  if (config.gridColor != null) {
    out.push(...encodeTag(7, 0), ...encodeVarintUnsigned(BigInt(config.gridColor >>> 0)));
  }
  if (config.allowResize != null) out.push(...encodeTag(9, 0), ...encodeBool(config.allowResize));
  return out;
}

// ColIndicatorConfig { visible=1, default_row_height=2, band_rows=3,
//   mode_bits=4, background=5, foreground=6, grid_lines=7, grid_color=8,
//   auto_size=9, allow_resize=10, allow_reorder=11, allow_menu=12 }

function encodeColIndicatorConfig(config: NonNullable<SheetGridConfig["indicators"]>["colTop"]): number[] {
  const out: number[] = [];
  if (!config) return out;
  if (config.visible != null) out.push(...encodeTag(1, 0), ...encodeBool(config.visible));
  if (config.defaultRowHeight != null) {
    out.push(...encodeTag(2, 0), ...encodeInt32(config.defaultRowHeight));
  }
  if (config.bandRows != null) out.push(...encodeTag(3, 0), ...encodeInt32(config.bandRows));
  if (config.modeBits != null) {
    out.push(...encodeTag(4, 0), ...encodeVarintUnsigned(BigInt(config.modeBits >>> 0)));
  }
  if (config.background != null) {
    out.push(...encodeTag(5, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    out.push(...encodeTag(6, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  if (config.gridLines != null) out.push(...encodeTag(7, 0), ...encodeInt32(config.gridLines));
  if (config.gridColor != null) {
    out.push(...encodeTag(8, 0), ...encodeVarintUnsigned(BigInt(config.gridColor >>> 0)));
  }
  if (config.allowResize != null) {
    out.push(...encodeTag(10, 0), ...encodeBool(config.allowResize));
  }
  return out;
}

// CornerIndicatorConfig { visible=1, mode_bits=2, background=3, foreground=4 }

function encodeCornerIndicatorConfig(
  config: NonNullable<SheetGridConfig["indicators"]>["cornerTopStart"],
): number[] {
  const out: number[] = [];
  if (!config) return out;
  if (config.visible != null) out.push(...encodeTag(1, 0), ...encodeBool(config.visible));
  if (config.modeBits != null) {
    out.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(config.modeBits >>> 0)));
  }
  if (config.background != null) {
    out.push(...encodeTag(3, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    out.push(...encodeTag(4, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  return out;
}

// ── Main encoder ────────────────────────────────────────────

export function encodeGridConfig(config: SheetGridConfig): Uint8Array {
  const gridConfig: number[] = [];

  // ── LayoutConfig (field 1) ──
  // LayoutConfig { rows=1, cols=2, fixed_rows=3, fixed_cols=4,
  //   frozen_rows=5, frozen_cols=6, default_row_height=7, default_col_width=8 }
  const layout: number[] = [];
  if (config.rows != null) layout.push(...encodeTag(1, 0), ...encodeInt32(config.rows));
  if (config.cols != null) layout.push(...encodeTag(2, 0), ...encodeInt32(config.cols));
  if (config.frozenRows != null) layout.push(...encodeTag(5, 0), ...encodeInt32(config.frozenRows));
  if (config.frozenCols != null) layout.push(...encodeTag(6, 0), ...encodeInt32(config.frozenCols));
  if (config.defaultRowHeight != null) layout.push(...encodeTag(7, 0), ...encodeInt32(config.defaultRowHeight));
  if (config.defaultColWidth != null) layout.push(...encodeTag(8, 0), ...encodeInt32(config.defaultColWidth));
  if (layout.length > 0) gridConfig.push(...encodeMessageField(1, layout));

  // ── StyleConfig (field 2) ──
  // StyleConfig { background=1, foreground=2, alternate_background=3,
  //   font=4, cell_padding=5, text_effect=6, progress_color=7,
  //   grid_lines=10, fixed=11, frozen=12, header=13,
  //   sheet_background=20, ..., text_overflow=43 }
  const style: number[] = [];
  if (config.background != null) {
    style.push(...encodeTag(1, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    style.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  if (config.alternateBackground != null) {
    style.push(...encodeTag(3, 0), ...encodeVarintUnsigned(BigInt(config.alternateBackground >>> 0)));
  }
  if (config.font) {
    const f = encodeFont(config.font);
    if (f.length > 0) style.push(...encodeMessageField(4, f));
  }
  if (config.gridLines) {
    const gl = encodeGridLines(config.gridLines);
    if (gl.length > 0) style.push(...encodeMessageField(10, gl));
  }
  if (config.fixed) {
    const rs = encodeRegionStyle(config.fixed);
    if (rs.length > 0) style.push(...encodeMessageField(11, rs));
  }
  if (config.textOverflow != null) {
    style.push(...encodeTag(43, 0), ...encodeBool(config.textOverflow));
  }
  if (style.length > 0) gridConfig.push(...encodeMessageField(2, style));

  // ── SelectionConfig (field 3) ──
  // SelectionConfig { mode=1, focus_border=2, visibility=3, allow=4,
  //   header_click_select=5, style=6, hover=7, indicator_row_style=8, indicator_col_style=9 }
  const selection: number[] = [];
  if (config.selectionMode != null) {
    selection.push(...encodeTag(1, 0), ...encodeInt32(config.selectionMode));
  }
  if (config.focusBorder != null) {
    selection.push(...encodeTag(2, 0), ...encodeInt32(config.focusBorder));
  }
  if (config.selectionStyle != null) {
    selection.push(...encodeMessageField(6, encodeHighlightStyle(config.selectionStyle)));
  }
  if (config.hover) {
    const h = encodeHoverConfig(config.hover);
    if (h.length > 0) selection.push(...encodeMessageField(7, h));
  }
  if (config.indicatorRowStyle != null) {
    selection.push(...encodeMessageField(8, encodeHighlightStyle(config.indicatorRowStyle)));
  }
  if (config.indicatorColStyle != null) {
    selection.push(...encodeMessageField(9, encodeHighlightStyle(config.indicatorColStyle)));
  }
  if (selection.length > 0) gridConfig.push(...encodeMessageField(3, selection));

  // ── EditConfig (field 4) ──
  // EditConfig { trigger=1, tab_behavior=2, ..., host_key_dispatch=7 }
  const editing: number[] = [];
  if (config.editTrigger != null) {
    editing.push(...encodeTag(1, 0), ...encodeInt32(config.editTrigger));
  }
  if (config.tabBehavior != null) {
    editing.push(...encodeTag(2, 0), ...encodeInt32(config.tabBehavior));
  }
  if (config.hostKeyDispatch != null) {
    editing.push(...encodeTag(7, 0), ...encodeBool(config.hostKeyDispatch));
  }
  if (editing.length > 0) gridConfig.push(...encodeMessageField(4, editing));

  // ── SpanConfig (field 7) ──
  // SpanConfig { cell_span=1, cell_span_fixed=2 }
  const span: number[] = [];
  if (config.cellSpan != null) {
    span.push(...encodeTag(1, 0), ...encodeInt32(config.cellSpan));
  }
  if (config.cellSpanFixed != null) {
    span.push(...encodeTag(2, 0), ...encodeInt32(config.cellSpanFixed));
  }
  if (span.length > 0) gridConfig.push(...encodeMessageField(7, span));

  // ── InteractionConfig (field 8) ──
  // InteractionConfig { resize=1, freeze=2, ..., auto_resize=7, ... }
  const interaction: number[] = [];
  if (config.resize) {
    const rp = encodeResizePolicy(config.resize);
    if (rp.length > 0) interaction.push(...encodeMessageField(1, rp));
  }
  if (config.autoResize != null) {
    interaction.push(...encodeTag(7, 0), ...encodeBool(config.autoResize));
  }
  if (interaction.length > 0) gridConfig.push(...encodeMessageField(8, interaction));

  // ── IndicatorsConfig (field 11) ──
  // IndicatorsConfig { row_start=1, row_end=2, col_top=3, col_bottom=4,
  //   corner_top_start=5, ... }
  const indicators: number[] = [];
  const rowStart = encodeRowIndicatorConfig(config.indicators?.rowStart);
  if (rowStart.length > 0) indicators.push(...encodeMessageField(1, rowStart));
  const colTop = encodeColIndicatorConfig(config.indicators?.colTop);
  if (colTop.length > 0) indicators.push(...encodeMessageField(3, colTop));
  const cornerTopStart = encodeCornerIndicatorConfig(config.indicators?.cornerTopStart);
  if (cornerTopStart.length > 0) indicators.push(...encodeMessageField(5, cornerTopStart));
  if (indicators.length > 0) gridConfig.push(...encodeMessageField(11, indicators));

  return new Uint8Array(gridConfig);
}
