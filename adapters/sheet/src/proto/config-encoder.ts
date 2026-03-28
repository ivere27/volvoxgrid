/**
 * Encode GridConfig for VolvoxGrid WASM.
 */

import {
  ColIndicatorConfigFields as ProtoColIndicatorConfigFields,
  CornerIndicatorConfigFields as ProtoCornerIndicatorConfigFields,
  GridConfigFields as ProtoGridConfigFields,
  GridLinesFields as ProtoGridLinesFields,
  HoverConfigFields as ProtoHoverConfigFields,
  IndicatorsConfigFields as ProtoIndicatorsConfigFields,
  InteractionConfigFields as ProtoInteractionConfigFields,
  LayoutConfigFields as ProtoLayoutConfigFields,
  RegionStyleFields as ProtoRegionStyleFields,
  ResizePolicyFields as ProtoResizePolicyFields,
  RowIndicatorConfigFields as ProtoRowIndicatorConfigFields,
  SelectionConfigFields as ProtoSelectionConfigFields,
  SpanConfigFields as ProtoSpanConfigFields,
  StyleConfigFields as ProtoStyleConfigFields,
  EditConfigFields as ProtoEditConfigFields,
} from "volvoxgrid/generated/volvoxgrid_ffi.js";
import {
  encodeTag,
  encodeInt32,
  encodeBool,
  encodeVarintUnsigned,
  encodeMessageField,
  encodeHighlightStyle,
  encodeFont,
  type HighlightStyleArg,
  type FontArg,
} from "./proto-utils.js";

export interface GridLinesArg {
  style?: number;
  direction?: number;
  color?: number;
  width?: number;
}

function encodeGridLines(gl: GridLinesArg): number[] {
  const out: number[] = [];
  if (gl.style != null) out.push(...encodeTag(ProtoGridLinesFields.style, 0), ...encodeInt32(gl.style));
  if (gl.direction != null) out.push(...encodeTag(ProtoGridLinesFields.direction, 0), ...encodeInt32(gl.direction));
  if (gl.color != null) {
    out.push(
      ...encodeTag(ProtoGridLinesFields.color, 0),
      ...encodeVarintUnsigned(BigInt(gl.color >>> 0)),
    );
  }
  if (gl.width != null) out.push(...encodeTag(ProtoGridLinesFields.width, 0), ...encodeInt32(gl.width));
  return out;
}

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
    out.push(
      ...encodeTag(ProtoRegionStyleFields.background, 0),
      ...encodeVarintUnsigned(BigInt(rs.background >>> 0)),
    );
  }
  if (rs.foreground != null) {
    out.push(
      ...encodeTag(ProtoRegionStyleFields.foreground, 0),
      ...encodeVarintUnsigned(BigInt(rs.foreground >>> 0)),
    );
  }
  if (rs.font) {
    const font = encodeFont(rs.font);
    if (font.length > 0) {
      out.push(...encodeMessageField(ProtoRegionStyleFields.font, font));
    }
  }
  if (rs.gridLines) {
    const gridLines = encodeGridLines(rs.gridLines);
    if (gridLines.length > 0) {
      out.push(...encodeMessageField(ProtoRegionStyleFields.grid_lines, gridLines));
    }
  }
  if (rs.textEffect != null) {
    out.push(...encodeTag(ProtoRegionStyleFields.text_effect, 0), ...encodeInt32(rs.textEffect));
  }
  return out;
}

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
  if (hover.row != null) out.push(...encodeTag(ProtoHoverConfigFields.row, 0), ...encodeBool(hover.row));
  if (hover.column != null) out.push(...encodeTag(ProtoHoverConfigFields.column, 0), ...encodeBool(hover.column));
  if (hover.cell != null) out.push(...encodeTag(ProtoHoverConfigFields.cell, 0), ...encodeBool(hover.cell));
  if (hover.rowStyle) out.push(...encodeMessageField(ProtoHoverConfigFields.row_style, encodeHighlightStyle(hover.rowStyle)));
  if (hover.columnStyle) out.push(...encodeMessageField(ProtoHoverConfigFields.column_style, encodeHighlightStyle(hover.columnStyle)));
  if (hover.cellStyle) out.push(...encodeMessageField(ProtoHoverConfigFields.cell_style, encodeHighlightStyle(hover.cellStyle)));
  return out;
}

export interface ResizePolicyArg {
  columns?: boolean;
  rows?: boolean;
  uniform?: boolean;
}

function encodeResizePolicy(rp: ResizePolicyArg): number[] {
  const out: number[] = [];
  if (rp.columns != null) out.push(...encodeTag(ProtoResizePolicyFields.columns, 0), ...encodeBool(rp.columns));
  if (rp.rows != null) out.push(...encodeTag(ProtoResizePolicyFields.rows, 0), ...encodeBool(rp.rows));
  if (rp.uniform != null) out.push(...encodeTag(ProtoResizePolicyFields.uniform, 0), ...encodeBool(rp.uniform));
  return out;
}

export interface SheetGridConfig {
  rows?: number;
  cols?: number;
  frozenRows?: number;
  frozenCols?: number;
  defaultRowHeight?: number;
  defaultColWidth?: number;
  background?: number;
  foreground?: number;
  alternateBackground?: number;
  font?: FontArg;
  gridLines?: GridLinesArg;
  fixed?: RegionStyleArg;
  textOverflow?: boolean;
  selectionMode?: number;
  focusBorder?: number;
  selectionStyle?: HighlightStyleArg;
  activeCellStyle?: HighlightStyleArg;
  hover?: HoverConfigArg;
  indicatorRowStyle?: HighlightStyleArg;
  indicatorColStyle?: HighlightStyleArg;
  editTrigger?: number;
  tabBehavior?: number;
  hostKeyDispatch?: boolean;
  resize?: ResizePolicyArg;
  autoResize?: boolean;
  cellSpan?: number;
  cellSpanFixed?: number;
  indicators?: {
    rowStart?: {
      visible?: boolean;
      width?: number;
      modeBits?: number;
      background?: number;
      foreground?: number;
      gridLines?: number;
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
      gridLines?: number;
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

function encodeRowIndicatorConfig(config: NonNullable<SheetGridConfig["indicators"]>["rowStart"]): number[] {
  const out: number[] = [];
  if (!config) return out;
  if (config.visible != null) out.push(...encodeTag(ProtoRowIndicatorConfigFields.visible, 0), ...encodeBool(config.visible));
  if (config.width != null) out.push(...encodeTag(ProtoRowIndicatorConfigFields.width, 0), ...encodeInt32(config.width));
  if (config.modeBits != null) {
    out.push(...encodeTag(ProtoRowIndicatorConfigFields.mode_bits, 0), ...encodeVarintUnsigned(BigInt(config.modeBits >>> 0)));
  }
  if (config.background != null) {
    out.push(...encodeTag(ProtoRowIndicatorConfigFields.background, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    out.push(...encodeTag(ProtoRowIndicatorConfigFields.foreground, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  if (config.gridLines != null) out.push(...encodeTag(ProtoRowIndicatorConfigFields.grid_lines, 0), ...encodeInt32(config.gridLines));
  if (config.gridColor != null) {
    out.push(...encodeTag(ProtoRowIndicatorConfigFields.grid_color, 0), ...encodeVarintUnsigned(BigInt(config.gridColor >>> 0)));
  }
  if (config.allowResize != null) out.push(...encodeTag(ProtoRowIndicatorConfigFields.allow_resize, 0), ...encodeBool(config.allowResize));
  return out;
}

function encodeColIndicatorConfig(config: NonNullable<SheetGridConfig["indicators"]>["colTop"]): number[] {
  const out: number[] = [];
  if (!config) return out;
  if (config.visible != null) out.push(...encodeTag(ProtoColIndicatorConfigFields.visible, 0), ...encodeBool(config.visible));
  if (config.defaultRowHeight != null) out.push(...encodeTag(ProtoColIndicatorConfigFields.default_row_height, 0), ...encodeInt32(config.defaultRowHeight));
  if (config.bandRows != null) out.push(...encodeTag(ProtoColIndicatorConfigFields.band_rows, 0), ...encodeInt32(config.bandRows));
  if (config.modeBits != null) {
    out.push(...encodeTag(ProtoColIndicatorConfigFields.mode_bits, 0), ...encodeVarintUnsigned(BigInt(config.modeBits >>> 0)));
  }
  if (config.background != null) {
    out.push(...encodeTag(ProtoColIndicatorConfigFields.background, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    out.push(...encodeTag(ProtoColIndicatorConfigFields.foreground, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  if (config.gridLines != null) out.push(...encodeTag(ProtoColIndicatorConfigFields.grid_lines, 0), ...encodeInt32(config.gridLines));
  if (config.gridColor != null) {
    out.push(...encodeTag(ProtoColIndicatorConfigFields.grid_color, 0), ...encodeVarintUnsigned(BigInt(config.gridColor >>> 0)));
  }
  if (config.allowResize != null) out.push(...encodeTag(ProtoColIndicatorConfigFields.allow_resize, 0), ...encodeBool(config.allowResize));
  return out;
}

function encodeCornerIndicatorConfig(config: NonNullable<SheetGridConfig["indicators"]>["cornerTopStart"]): number[] {
  const out: number[] = [];
  if (!config) return out;
  if (config.visible != null) out.push(...encodeTag(ProtoCornerIndicatorConfigFields.visible, 0), ...encodeBool(config.visible));
  if (config.modeBits != null) {
    out.push(...encodeTag(ProtoCornerIndicatorConfigFields.mode_bits, 0), ...encodeVarintUnsigned(BigInt(config.modeBits >>> 0)));
  }
  if (config.background != null) {
    out.push(...encodeTag(ProtoCornerIndicatorConfigFields.background, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    out.push(...encodeTag(ProtoCornerIndicatorConfigFields.foreground, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  return out;
}

export function encodeGridConfig(config: SheetGridConfig): Uint8Array {
  const gridConfig: number[] = [];

  const layout: number[] = [];
  if (config.rows != null) layout.push(...encodeTag(ProtoLayoutConfigFields.rows, 0), ...encodeInt32(config.rows));
  if (config.cols != null) layout.push(...encodeTag(ProtoLayoutConfigFields.cols, 0), ...encodeInt32(config.cols));
  if (config.frozenRows != null) layout.push(...encodeTag(ProtoLayoutConfigFields.frozen_rows, 0), ...encodeInt32(config.frozenRows));
  if (config.frozenCols != null) layout.push(...encodeTag(ProtoLayoutConfigFields.frozen_cols, 0), ...encodeInt32(config.frozenCols));
  if (config.defaultRowHeight != null) layout.push(...encodeTag(ProtoLayoutConfigFields.default_row_height, 0), ...encodeInt32(config.defaultRowHeight));
  if (config.defaultColWidth != null) layout.push(...encodeTag(ProtoLayoutConfigFields.default_col_width, 0), ...encodeInt32(config.defaultColWidth));
  if (layout.length > 0) gridConfig.push(...encodeMessageField(ProtoGridConfigFields.layout, layout));

  const style: number[] = [];
  if (config.background != null) {
    style.push(...encodeTag(ProtoStyleConfigFields.background, 0), ...encodeVarintUnsigned(BigInt(config.background >>> 0)));
  }
  if (config.foreground != null) {
    style.push(...encodeTag(ProtoStyleConfigFields.foreground, 0), ...encodeVarintUnsigned(BigInt(config.foreground >>> 0)));
  }
  if (config.alternateBackground != null) {
    style.push(...encodeTag(ProtoStyleConfigFields.alternate_background, 0), ...encodeVarintUnsigned(BigInt(config.alternateBackground >>> 0)));
  }
  if (config.font) {
    const font = encodeFont(config.font);
    if (font.length > 0) style.push(...encodeMessageField(ProtoStyleConfigFields.font, font));
  }
  if (config.gridLines) {
    const gridLines = encodeGridLines(config.gridLines);
    if (gridLines.length > 0) style.push(...encodeMessageField(ProtoStyleConfigFields.grid_lines, gridLines));
  }
  if (config.fixed) {
    const fixed = encodeRegionStyle(config.fixed);
    if (fixed.length > 0) style.push(...encodeMessageField(ProtoStyleConfigFields.fixed, fixed));
  }
  if (config.textOverflow != null) {
    style.push(...encodeTag(ProtoStyleConfigFields.text_overflow, 0), ...encodeBool(config.textOverflow));
  }
  if (style.length > 0) gridConfig.push(...encodeMessageField(ProtoGridConfigFields.style, style));

  const selection: number[] = [];
  if (config.selectionMode != null) selection.push(...encodeTag(ProtoSelectionConfigFields.mode, 0), ...encodeInt32(config.selectionMode));
  if (config.focusBorder != null) selection.push(...encodeTag(ProtoSelectionConfigFields.focus_border, 0), ...encodeInt32(config.focusBorder));
  if (config.selectionStyle != null) selection.push(...encodeMessageField(ProtoSelectionConfigFields.style, encodeHighlightStyle(config.selectionStyle)));
  if (config.activeCellStyle != null) selection.push(...encodeMessageField(ProtoSelectionConfigFields.active_cell_style, encodeHighlightStyle(config.activeCellStyle)));
  if (config.hover) {
    const hover = encodeHoverConfig(config.hover);
    if (hover.length > 0) selection.push(...encodeMessageField(ProtoSelectionConfigFields.hover, hover));
  }
  if (config.indicatorRowStyle != null) selection.push(...encodeMessageField(ProtoSelectionConfigFields.indicator_row_style, encodeHighlightStyle(config.indicatorRowStyle)));
  if (config.indicatorColStyle != null) selection.push(...encodeMessageField(ProtoSelectionConfigFields.indicator_col_style, encodeHighlightStyle(config.indicatorColStyle)));
  if (selection.length > 0) gridConfig.push(...encodeMessageField(ProtoGridConfigFields.selection, selection));

  const editing: number[] = [];
  if (config.editTrigger != null) editing.push(...encodeTag(ProtoEditConfigFields.trigger, 0), ...encodeInt32(config.editTrigger));
  if (config.tabBehavior != null) editing.push(...encodeTag(ProtoEditConfigFields.tab_behavior, 0), ...encodeInt32(config.tabBehavior));
  if (config.hostKeyDispatch != null) editing.push(...encodeTag(ProtoEditConfigFields.host_key_dispatch, 0), ...encodeBool(config.hostKeyDispatch));
  if (editing.length > 0) gridConfig.push(...encodeMessageField(ProtoGridConfigFields.editing, editing));

  const span: number[] = [];
  if (config.cellSpan != null) span.push(...encodeTag(ProtoSpanConfigFields.cell_span, 0), ...encodeInt32(config.cellSpan));
  if (config.cellSpanFixed != null) span.push(...encodeTag(ProtoSpanConfigFields.cell_span_fixed, 0), ...encodeInt32(config.cellSpanFixed));
  if (span.length > 0) gridConfig.push(...encodeMessageField(ProtoGridConfigFields.span, span));

  const interaction: number[] = [];
  if (config.resize) {
    const resize = encodeResizePolicy(config.resize);
    if (resize.length > 0) interaction.push(...encodeMessageField(ProtoInteractionConfigFields.resize, resize));
  }
  if (config.autoResize != null) interaction.push(...encodeTag(ProtoInteractionConfigFields.auto_resize, 0), ...encodeBool(config.autoResize));
  if (interaction.length > 0) gridConfig.push(...encodeMessageField(ProtoGridConfigFields.interaction, interaction));

  const indicators: number[] = [];
  const rowStart = encodeRowIndicatorConfig(config.indicators?.rowStart);
  if (rowStart.length > 0) indicators.push(...encodeMessageField(ProtoIndicatorsConfigFields.row_start, rowStart));
  const colTop = encodeColIndicatorConfig(config.indicators?.colTop);
  if (colTop.length > 0) indicators.push(...encodeMessageField(ProtoIndicatorsConfigFields.col_top, colTop));
  const cornerTopStart = encodeCornerIndicatorConfig(config.indicators?.cornerTopStart);
  if (cornerTopStart.length > 0) indicators.push(...encodeMessageField(ProtoIndicatorsConfigFields.corner_top_start, cornerTopStart));
  if (indicators.length > 0) gridConfig.push(...encodeMessageField(ProtoGridConfigFields.indicators, indicators));

  return new Uint8Array(gridConfig);
}
