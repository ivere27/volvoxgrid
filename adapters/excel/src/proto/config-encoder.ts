/**
 * Encode GridConfig (ConfigureRequest) for VolvoxGrid WASM.
 *
 * ConfigureRequest { grid_id=1, config=2 { GridConfig } }
 * GridConfig { layout=1, style=2, selection=3, editing=4, ... }
 */

import {
  encodeTag, encodeInt32, encodeBool,
  encodeVarintUnsigned, encodeMessageField, encodeStringField, encodeHighlightStyle,
  type HighlightStyleArg,
} from "./proto-utils.js";

export interface ExcelGridConfig {
  // Layout
  rows?: number;
  cols?: number;
  frozenRows?: number;
  frozenCols?: number;
  defaultRowHeight?: number;
  defaultColWidth?: number;
  // Style
  backColor?: number;
  foreColor?: number;
  backColorFixed?: number;
  foreColorFixed?: number;
  gridLines?: number;
  gridLinesFixed?: number;
  gridColor?: number;
  gridColorFixed?: number;
  gridLineWidth?: number;
  fontName?: string;
  fontSize?: number;
  fontBold?: boolean;
  // Selection
  selectionMode?: number;
  focusBorder?: number;
  selectionStyle?: HighlightStyleArg;
  hoverMode?: number;
  hoverRowStyle?: HighlightStyleArg;
  hoverColumnStyle?: HighlightStyleArg;
  hoverCellStyle?: HighlightStyleArg;
  // Edit
  editTrigger?: number;
  tabBehavior?: number;
  hostKeyDispatch?: boolean;
  // Interaction
  allowUserResizing?: number;
  autoResize?: boolean;
  // Span
  cellSpan?: number;
  cellSpanFixed?: number;
  // Text overflow
  textOverflow?: boolean;
}

export function encodeGridConfig(config: ExcelGridConfig): Uint8Array {
  const gridConfig: number[] = [];

  // ── LayoutConfig (field 1) ──
  const layout: number[] = [];
  if (config.rows != null) layout.push(...encodeTag(1, 0), ...encodeInt32(config.rows));
  if (config.cols != null) layout.push(...encodeTag(2, 0), ...encodeInt32(config.cols));
  if (config.frozenRows != null) layout.push(...encodeTag(5, 0), ...encodeInt32(config.frozenRows));
  if (config.frozenCols != null) layout.push(...encodeTag(6, 0), ...encodeInt32(config.frozenCols));
  if (config.defaultRowHeight != null) layout.push(...encodeTag(7, 0), ...encodeInt32(config.defaultRowHeight));
  if (config.defaultColWidth != null) layout.push(...encodeTag(8, 0), ...encodeInt32(config.defaultColWidth));
  if (config.textOverflow != null) layout.push(...encodeTag(14, 0), ...encodeBool(config.textOverflow));
  if (layout.length > 0) gridConfig.push(...encodeMessageField(1, layout));

  // ── StyleConfig (field 2) ──
  const style: number[] = [];
  if (config.backColor != null) {
    style.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(config.backColor >>> 0)));
  }
  if (config.foreColor != null) {
    style.push(...encodeTag(3, 0), ...encodeVarintUnsigned(BigInt(config.foreColor >>> 0)));
  }
  if (config.backColorFixed != null) {
    style.push(...encodeTag(4, 0), ...encodeVarintUnsigned(BigInt(config.backColorFixed >>> 0)));
  }
  if (config.foreColorFixed != null) {
    style.push(...encodeTag(5, 0), ...encodeVarintUnsigned(BigInt(config.foreColorFixed >>> 0)));
  }
  if (config.gridLines != null) {
    style.push(...encodeTag(12, 0), ...encodeInt32(config.gridLines));
  }
  if (config.gridLinesFixed != null) {
    style.push(...encodeTag(13, 0), ...encodeInt32(config.gridLinesFixed));
  }
  if (config.gridColor != null) {
    style.push(...encodeTag(14, 0), ...encodeVarintUnsigned(BigInt(config.gridColor >>> 0)));
  }
  if (config.gridColorFixed != null) {
    style.push(...encodeTag(15, 0), ...encodeVarintUnsigned(BigInt(config.gridColorFixed >>> 0)));
  }
  if (config.gridLineWidth != null) {
    style.push(...encodeTag(16, 0), ...encodeInt32(config.gridLineWidth));
  }
  if (config.fontName != null) {
    style.push(...encodeStringField(19, config.fontName));
  }
  if (config.fontSize != null) {
    // StyleConfig.font_size = 20 (float, wire type 5)
    const buf = new ArrayBuffer(4);
    new DataView(buf).setFloat32(0, config.fontSize, true);
    const bytes = new Uint8Array(buf);
    style.push(...encodeTag(20, 5), ...bytes);
  }
  if (config.fontBold != null) {
    style.push(...encodeTag(21, 0), ...encodeBool(config.fontBold));
  }
  if (style.length > 0) gridConfig.push(...encodeMessageField(2, style));

  // ── SelectionConfig (field 3) ──
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
  if (config.hoverMode != null) {
    selection.push(...encodeTag(7, 0), ...encodeVarintUnsigned(BigInt(config.hoverMode >>> 0)));
  }
  if (config.hoverRowStyle != null) {
    selection.push(...encodeMessageField(8, encodeHighlightStyle(config.hoverRowStyle)));
  }
  if (config.hoverColumnStyle != null) {
    selection.push(...encodeMessageField(9, encodeHighlightStyle(config.hoverColumnStyle)));
  }
  if (config.hoverCellStyle != null) {
    selection.push(...encodeMessageField(10, encodeHighlightStyle(config.hoverCellStyle)));
  }
  if (selection.length > 0) gridConfig.push(...encodeMessageField(3, selection));

  // ── EditConfig (field 4) ──
  const editing: number[] = [];
  if (config.editTrigger != null) {
    editing.push(...encodeTag(1, 0), ...encodeInt32(config.editTrigger));
  }
  if (config.tabBehavior != null) {
    editing.push(...encodeTag(2, 0), ...encodeInt32(config.tabBehavior));
  }
  if (config.hostKeyDispatch != null) {
    // EditConfig.host_key_dispatch = 7
    editing.push(...encodeTag(7, 0), ...encodeBool(config.hostKeyDispatch));
  }
  if (editing.length > 0) gridConfig.push(...encodeMessageField(4, editing));

  // ── InteractionConfig (field 8) ──
  const interaction: number[] = [];
  if (config.allowUserResizing != null) {
    interaction.push(...encodeTag(1, 0), ...encodeInt32(config.allowUserResizing));
  }
  if (config.autoResize != null) {
    interaction.push(...encodeTag(7, 0), ...encodeBool(config.autoResize));
  }
  if (interaction.length > 0) gridConfig.push(...encodeMessageField(8, interaction));

  // ── SpanConfig (field 7) ──
  const span: number[] = [];
  if (config.cellSpan != null) {
    span.push(...encodeTag(1, 0), ...encodeInt32(config.cellSpan));
  }
  if (config.cellSpanFixed != null) {
    span.push(...encodeTag(2, 0), ...encodeInt32(config.cellSpanFixed));
  }
  if (span.length > 0) gridConfig.push(...encodeMessageField(7, span));

  return new Uint8Array(gridConfig);
}
