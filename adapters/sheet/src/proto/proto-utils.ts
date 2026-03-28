/**
 * Manual protobuf encode/decode utilities.
 * Follows the same hand-rolled pattern as adapters/aggrid/src/proto-utils.ts.
 */

import {
  BorderFields as ProtoBorderFields,
  BordersFields as ProtoBordersFields,
  CellRangeFields as ProtoCellRangeFields,
  CellStyleFields as ProtoCellStyleFields,
  CellUpdateFields as ProtoCellUpdateFields,
  CellValueFields as ProtoCellValueFields,
  EditCommandFields as ProtoEditCommandFields,
  EditCommitFields as ProtoEditCommitFields,
  EditSetHighlightsFields as ProtoEditSetHighlightsFields,
  EditSetTextFields as ProtoEditSetTextFields,
  EditStartFields as ProtoEditStartFields,
  FontFields as ProtoFontFields,
  HighlightRegionFields as ProtoHighlightRegionFields,
  HighlightStyleFields as ProtoHighlightStyleFields,
  InsertRowsRequestFields as ProtoInsertRowsRequestFields,
  SelectRequestFields as ProtoSelectRequestFields,
  SelectionStateFields as ProtoSelectionStateFields,
  UpdateCellsRequestFields as ProtoUpdateCellsRequestFields,
} from "volvoxgrid/generated/volvoxgrid_ffi.js";

const TEXT_ENCODER = new TextEncoder();
const TEXT_DECODER = new TextDecoder();

export function encodeVarintUnsigned(value: bigint): number[] {
  const out: number[] = [];
  let v = BigInt.asUintN(64, value);
  while (v >= 0x80n) {
    out.push(Number((v & 0x7fn) | 0x80n));
    v >>= 7n;
  }
  out.push(Number(v));
  return out;
}

export function encodeTag(field: number, wireType: number): number[] {
  return encodeVarintUnsigned(BigInt((field << 3) | wireType));
}

export function encodeInt32(value: number): number[] {
  const i32 = BigInt.asIntN(32, BigInt(Math.trunc(value)));
  return encodeVarintUnsigned(BigInt.asUintN(64, i32));
}

export function encodeInt64(value: number): number[] {
  return encodeVarintUnsigned(BigInt(Math.trunc(value)));
}

export function encodeBool(value: boolean): number[] {
  return encodeVarintUnsigned(value ? 1n : 0n);
}

export function encodeString(value: string): number[] {
  const data = TEXT_ENCODER.encode(value);
  return [...encodeVarintUnsigned(BigInt(data.length)), ...data];
}

export function encodeStringField(field: number, value: string): number[] {
  const data = TEXT_ENCODER.encode(value);
  return [
    ...encodeTag(field, 2),
    ...encodeVarintUnsigned(BigInt(data.length)),
    ...data,
  ];
}

export function encodeMessageField(field: number, payload: number[]): number[] {
  return [
    ...encodeTag(field, 2),
    ...encodeVarintUnsigned(BigInt(payload.length)),
    ...payload,
  ];
}

function encodeCellRange(row1: number, col1: number, row2: number, col2: number): number[] {
  const out: number[] = [];
  out.push(...encodeTag(ProtoCellRangeFields.row1, 0), ...encodeInt32(row1));
  out.push(...encodeTag(ProtoCellRangeFields.col1, 0), ...encodeInt32(col1));
  out.push(...encodeTag(ProtoCellRangeFields.row2, 0), ...encodeInt32(row2));
  out.push(...encodeTag(ProtoCellRangeFields.col2, 0), ...encodeInt32(col2));
  return out;
}

function decodeCellRange(data: Uint8Array): { row1: number; col1: number; row2: number; col2: number } {
  let row1 = -1;
  let col1 = -1;
  let row2 = -1;
  let col2 = -1;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const value = readVarint(data, offset);
      offset = value.next;
      const n = asInt32(value.value);
      if (field === ProtoCellRangeFields.row1) row1 = n;
      if (field === ProtoCellRangeFields.col1) col1 = n;
      if (field === ProtoCellRangeFields.row2) row2 = n;
      if (field === ProtoCellRangeFields.col2) col2 = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { row1, col1, row2, col2 };
}

export interface BorderArg {
  style?: number;
  color?: number;
}

export interface BordersArg {
  all?: BorderArg;
  top?: BorderArg;
  right?: BorderArg;
  bottom?: BorderArg;
  left?: BorderArg;
}

export interface HighlightStyleArg {
  background?: number;
  foreground?: number;
  borders?: BordersArg;
  fillHandle?: number;
  fillHandleColor?: number;
}

export function encodeBorder(border: BorderArg): number[] {
  const out: number[] = [];
  if (border.style != null) out.push(...encodeTag(ProtoBorderFields.style, 0), ...encodeInt32(border.style));
  if (border.color != null) {
    out.push(...encodeTag(ProtoBorderFields.color, 0), ...encodeVarintUnsigned(BigInt(border.color >>> 0)));
  }
  return out;
}

export function encodeBorders(borders: BordersArg): number[] {
  const out: number[] = [];
  if (borders.all) out.push(...encodeMessageField(ProtoBordersFields.all, encodeBorder(borders.all)));
  if (borders.top) out.push(...encodeMessageField(ProtoBordersFields.top, encodeBorder(borders.top)));
  if (borders.right) out.push(...encodeMessageField(ProtoBordersFields.right, encodeBorder(borders.right)));
  if (borders.bottom) out.push(...encodeMessageField(ProtoBordersFields.bottom, encodeBorder(borders.bottom)));
  if (borders.left) out.push(...encodeMessageField(ProtoBordersFields.left, encodeBorder(borders.left)));
  return out;
}

export function encodeHighlightStyle(style: HighlightStyleArg): number[] {
  const out: number[] = [];
  if (style.background != null) {
    out.push(...encodeTag(ProtoHighlightStyleFields.background, 0), ...encodeVarintUnsigned(BigInt(style.background >>> 0)));
  }
  if (style.foreground != null) {
    out.push(...encodeTag(ProtoHighlightStyleFields.foreground, 0), ...encodeVarintUnsigned(BigInt(style.foreground >>> 0)));
  }
  if (style.borders) {
    const borders = encodeBorders(style.borders);
    if (borders.length > 0) out.push(...encodeMessageField(ProtoHighlightStyleFields.borders, borders));
  }
  if (style.fillHandle != null) {
    out.push(...encodeTag(ProtoHighlightStyleFields.fill_handle, 0), ...encodeInt32(style.fillHandle));
  }
  if (style.fillHandleColor != null) {
    out.push(...encodeTag(ProtoHighlightStyleFields.fill_handle_color, 0), ...encodeVarintUnsigned(BigInt(style.fillHandleColor >>> 0)));
  }
  return out;
}

export function readVarint(data: Uint8Array, offset: number): { value: bigint; next: number } {
  let out = 0n;
  let shift = 0n;
  let i = offset;
  while (i < data.length) {
    const b = data[i];
    out |= BigInt(b & 0x7f) << shift;
    i += 1;
    if ((b & 0x80) === 0) {
      return { value: out, next: i };
    }
    shift += 7n;
    if (shift > 70n) break;
  }
  return { value: 0n, next: data.length };
}

export function skipField(data: Uint8Array, offset: number, wireType: number): number {
  if (wireType === 0) return readVarint(data, offset).next;
  if (wireType === 1) return Math.min(data.length, offset + 8);
  if (wireType === 2) {
    const length = readVarint(data, offset);
    const n = Number(length.value);
    if (!Number.isFinite(n) || n < 0) return data.length;
    return Math.min(data.length, length.next + n);
  }
  if (wireType === 5) return Math.min(data.length, offset + 4);
  return data.length;
}

export function asInt32(value: bigint): number {
  return Number(BigInt.asIntN(32, value));
}

export function readLengthDelimited(data: Uint8Array, offset: number): { data: Uint8Array; next: number } {
  const length = readVarint(data, offset);
  const n = Number(length.value);
  if (!Number.isFinite(n) || n < 0) {
    return { data: new Uint8Array(0), next: data.length };
  }
  const start = length.next;
  const end = Math.min(data.length, start + n);
  return { data: data.slice(start, end), next: end };
}

export function readString(data: Uint8Array, offset: number): { value: string; next: number } {
  const ld = readLengthDelimited(data, offset);
  return { value: TEXT_DECODER.decode(ld.data), next: ld.next };
}

export function encodeEditStart(args: {
  gridId: number;
  row: number;
  col: number;
  selectAll?: boolean;
  caretEnd?: boolean;
  seedText?: string;
  formulaMode?: boolean;
}): Uint8Array {
  const start: number[] = [];
  start.push(...encodeTag(ProtoEditStartFields.row, 0), ...encodeInt32(args.row));
  start.push(...encodeTag(ProtoEditStartFields.col, 0), ...encodeInt32(args.col));
  if (args.selectAll != null) {
    start.push(...encodeTag(ProtoEditStartFields.select_all, 0), ...encodeBool(args.selectAll));
  }
  if (args.caretEnd != null) {
    start.push(...encodeTag(ProtoEditStartFields.caret_end, 0), ...encodeBool(args.caretEnd));
  }
  if (args.seedText != null) {
    start.push(...encodeStringField(ProtoEditStartFields.seed_text, args.seedText));
  }
  if (args.formulaMode != null) {
    start.push(...encodeTag(ProtoEditStartFields.formula_mode, 0), ...encodeBool(args.formulaMode));
  }

  const out: number[] = [];
  out.push(...encodeTag(ProtoEditCommandFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeMessageField(ProtoEditCommandFields.start, start));
  return new Uint8Array(out);
}

export function encodeEditCommit(args: {
  gridId: number;
  text?: string;
}): Uint8Array {
  const commit: number[] = [];
  if (args.text != null) {
    commit.push(...encodeStringField(ProtoEditCommitFields.text, args.text));
  }

  const out: number[] = [];
  out.push(...encodeTag(ProtoEditCommandFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeMessageField(ProtoEditCommandFields.commit, commit));
  return new Uint8Array(out);
}

export function encodeEditCancel(gridId: number): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(ProtoEditCommandFields.grid_id, 0), ...encodeInt64(gridId));
  out.push(...encodeMessageField(ProtoEditCommandFields.cancel, []));
  return new Uint8Array(out);
}

export function encodeEditSetText(args: {
  gridId: number;
  text: string;
}): Uint8Array {
  const setText: number[] = [];
  setText.push(...encodeStringField(ProtoEditSetTextFields.text, args.text));

  const out: number[] = [];
  out.push(...encodeTag(ProtoEditCommandFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeMessageField(ProtoEditCommandFields.set_text, setText));
  return new Uint8Array(out);
}

export interface HighlightRegionArg {
  row1: number;
  col1: number;
  row2: number;
  col2: number;
  style: HighlightStyleArg;
  refId?: number;
  textStart?: number;
  textLength?: number;
}

export function encodeEditSetHighlights(args: {
  gridId: number;
  regions: HighlightRegionArg[];
}): Uint8Array {
  const setHighlights: number[] = [];
  for (const region of args.regions) {
    const regionMsg: number[] = [];
    regionMsg.push(...encodeMessageField(
      ProtoHighlightRegionFields.range,
      encodeCellRange(region.row1, region.col1, region.row2, region.col2),
    ));
    regionMsg.push(...encodeMessageField(ProtoHighlightRegionFields.style, encodeHighlightStyle(region.style)));
    if (region.refId != null) {
      regionMsg.push(...encodeTag(ProtoHighlightRegionFields.ref_id, 0), ...encodeInt32(region.refId));
    }
    if (region.textStart != null) {
      regionMsg.push(...encodeTag(ProtoHighlightRegionFields.text_start, 0), ...encodeInt32(region.textStart));
    }
    if (region.textLength != null) {
      regionMsg.push(...encodeTag(ProtoHighlightRegionFields.text_length, 0), ...encodeInt32(region.textLength));
    }
    setHighlights.push(...encodeMessageField(ProtoEditSetHighlightsFields.regions, regionMsg));
  }

  const out: number[] = [];
  out.push(...encodeTag(ProtoEditCommandFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeMessageField(ProtoEditCommandFields.set_highlights, setHighlights));
  return new Uint8Array(out);
}

export function encodeSelectRequest(args: {
  gridId: number;
  row: number;
  col: number;
  rowEnd?: number;
  colEnd?: number;
  ranges?: ReadonlyArray<{ row1: number; col1: number; row2: number; col2: number }>;
  show?: boolean;
}): Uint8Array {
  const out: number[] = [];
  const rowEnd = args.rowEnd ?? args.row;
  const colEnd = args.colEnd ?? args.col;
  const ranges = args.ranges && args.ranges.length > 0
    ? args.ranges
    : [{ row1: args.row, col1: args.col, row2: rowEnd, col2: colEnd }];

  out.push(...encodeTag(ProtoSelectRequestFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeTag(ProtoSelectRequestFields.active_row, 0), ...encodeInt32(args.row));
  out.push(...encodeTag(ProtoSelectRequestFields.active_col, 0), ...encodeInt32(args.col));
  for (const range of ranges) {
    out.push(...encodeMessageField(
      ProtoSelectRequestFields.ranges,
      encodeCellRange(range.row1, range.col1, range.row2, range.col2),
    ));
  }
  if (args.show != null) {
    out.push(...encodeTag(ProtoSelectRequestFields.show, 0), ...encodeBool(args.show));
  }
  return new Uint8Array(out);
}

export interface FontArg {
  family?: string;
  size?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  width?: number;
}

export interface CellStyleFields {
  backColor?: number;
  foreColor?: number;
  alignment?: number;
  fontBold?: boolean;
  fontItalic?: boolean;
  fontUnderline?: boolean;
  fontStrikethrough?: boolean;
  fontName?: string;
  fontSize?: number;
  borderTop?: number;
  borderRight?: number;
  borderBottom?: number;
  borderLeft?: number;
  borderTopColor?: number;
  borderRightColor?: number;
  borderBottomColor?: number;
  borderLeftColor?: number;
  shrinkToFit?: boolean;
}

export function encodeFont(font: FontArg): number[] {
  const out: number[] = [];
  if (font.family != null) out.push(...encodeStringField(ProtoFontFields.family, font.family));
  if (font.size != null) {
    const buf = new ArrayBuffer(4);
    new DataView(buf).setFloat32(0, font.size, true);
    out.push(...encodeTag(ProtoFontFields.size, 5), ...new Uint8Array(buf));
  }
  if (font.bold != null) out.push(...encodeTag(ProtoFontFields.bold, 0), ...encodeBool(font.bold));
  if (font.italic != null) out.push(...encodeTag(ProtoFontFields.italic, 0), ...encodeBool(font.italic));
  if (font.underline != null) out.push(...encodeTag(ProtoFontFields.underline, 0), ...encodeBool(font.underline));
  if (font.strikethrough != null) out.push(...encodeTag(ProtoFontFields.strikethrough, 0), ...encodeBool(font.strikethrough));
  if (font.width != null) {
    const buf = new ArrayBuffer(4);
    new DataView(buf).setFloat32(0, font.width, true);
    out.push(...encodeTag(ProtoFontFields.width, 5), ...new Uint8Array(buf));
  }
  return out;
}

function encodeCellStyle(style: CellStyleFields): number[] {
  const out: number[] = [];
  if (typeof style.backColor === "number") {
    out.push(...encodeTag(ProtoCellStyleFields.background, 0), ...encodeVarintUnsigned(BigInt(style.backColor >>> 0)));
  }
  if (typeof style.foreColor === "number") {
    out.push(...encodeTag(ProtoCellStyleFields.foreground, 0), ...encodeVarintUnsigned(BigInt(style.foreColor >>> 0)));
  }
  if (typeof style.alignment === "number") {
    out.push(...encodeTag(ProtoCellStyleFields.align, 0), ...encodeInt32(style.alignment));
  }

  const font: FontArg = {};
  if (typeof style.fontName === "string") font.family = style.fontName;
  if (typeof style.fontSize === "number") font.size = style.fontSize;
  if (typeof style.fontBold === "boolean") font.bold = style.fontBold;
  if (typeof style.fontItalic === "boolean") font.italic = style.fontItalic;
  if (typeof style.fontUnderline === "boolean") font.underline = style.fontUnderline;
  if (typeof style.fontStrikethrough === "boolean") font.strikethrough = style.fontStrikethrough;
  const fontBytes = encodeFont(font);
  if (fontBytes.length > 0) out.push(...encodeMessageField(ProtoCellStyleFields.font, fontBytes));

  const borders: BordersArg = {};
  if (style.borderTop != null || style.borderTopColor != null) {
    borders.top = { style: style.borderTop, color: style.borderTopColor };
  }
  if (style.borderRight != null || style.borderRightColor != null) {
    borders.right = { style: style.borderRight, color: style.borderRightColor };
  }
  if (style.borderBottom != null || style.borderBottomColor != null) {
    borders.bottom = { style: style.borderBottom, color: style.borderBottomColor };
  }
  if (style.borderLeft != null || style.borderLeftColor != null) {
    borders.left = { style: style.borderLeft, color: style.borderLeftColor };
  }
  const bordersBytes = encodeBorders(borders);
  if (bordersBytes.length > 0) out.push(...encodeMessageField(ProtoCellStyleFields.borders, bordersBytes));

  if (typeof style.shrinkToFit === "boolean") {
    out.push(...encodeTag(ProtoCellStyleFields.shrink_to_fit, 0), ...encodeBool(style.shrinkToFit));
  }
  return out;
}

export interface CellUpdateEntry {
  row: number;
  col: number;
  text?: string;
  style?: CellStyleFields;
}

export function encodeUpdateCellsRequest(args: {
  gridId: number;
  updates: CellUpdateEntry[];
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(ProtoUpdateCellsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const update of args.updates) {
    const cellUpdate: number[] = [];
    cellUpdate.push(...encodeTag(ProtoCellUpdateFields.row, 0), ...encodeInt32(update.row));
    cellUpdate.push(...encodeTag(ProtoCellUpdateFields.col, 0), ...encodeInt32(update.col));

    if (update.text != null) {
      const cellValue: number[] = [];
      cellValue.push(...encodeStringField(ProtoCellValueFields.text, update.text));
      cellUpdate.push(...encodeMessageField(ProtoCellUpdateFields.value, cellValue));
    }

    if (update.style) {
      const style = encodeCellStyle(update.style);
      if (style.length > 0) {
        cellUpdate.push(...encodeMessageField(ProtoCellUpdateFields.style, style));
      }
    }

    out.push(...encodeMessageField(ProtoUpdateCellsRequestFields.cells, cellUpdate));
  }

  return new Uint8Array(out);
}

export function encodeInsertRowsRequest(args: {
  gridId: number;
  index: number;
  count: number;
  text?: string[];
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(ProtoInsertRowsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeTag(ProtoInsertRowsRequestFields.index, 0), ...encodeInt32(args.index));
  out.push(...encodeTag(ProtoInsertRowsRequestFields.count, 0), ...encodeInt32(args.count));
  if (args.text) {
    for (const rowText of args.text) {
      out.push(...encodeStringField(ProtoInsertRowsRequestFields.text, rowText));
    }
  }
  return new Uint8Array(out);
}

export interface SelectionState {
  row: number;
  col: number;
  rowEnd: number;
  colEnd: number;
}

export function decodeSelectionState(data: Uint8Array): SelectionState {
  const out: SelectionState = { row: -1, col: -1, rowEnd: -1, colEnd: -1 };
  let activeRow = -1;
  let activeCol = -1;
  let lastRange: { row1: number; col1: number; row2: number; col2: number } | null = null;
  let hasRanges = false;
  let bottomRow = -1;
  let rightCol = -1;
  let offset = 0;

  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === ProtoSelectionStateFields.ranges && wire === 2) {
      const ld = readLengthDelimited(data, offset);
      offset = ld.next;
      lastRange = decodeCellRange(ld.data);
      hasRanges = true;
      continue;
    }
    if (wire === 0) {
      const value = readVarint(data, offset);
      offset = value.next;
      const n = asInt32(value.value);
      if (field === ProtoSelectionStateFields.active_row) activeRow = n;
      if (field === ProtoSelectionStateFields.active_col) activeCol = n;
      if (field === ProtoSelectionStateFields.bottom_row) bottomRow = n;
      if (field === ProtoSelectionStateFields.right_col) rightCol = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }

  out.row = activeRow;
  out.col = activeCol;

  if (lastRange != null) {
    if (activeRow === lastRange.row1 && activeCol === lastRange.col1) {
      out.rowEnd = lastRange.row2;
      out.colEnd = lastRange.col2;
    } else if (activeRow === lastRange.row2 && activeCol === lastRange.col2) {
      out.rowEnd = lastRange.row1;
      out.colEnd = lastRange.col1;
    } else {
      out.rowEnd = lastRange.row2;
      out.colEnd = lastRange.col2;
    }
  } else {
    out.rowEnd = bottomRow >= 0 ? bottomRow : activeRow;
    out.colEnd = rightCol >= 0 ? rightCol : activeCol;
    if (!hasRanges && out.rowEnd < 0) out.rowEnd = out.row;
    if (!hasRanges && out.colEnd < 0) out.colEnd = out.col;
  }

  return out;
}
