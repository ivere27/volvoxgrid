/**
 * Manual protobuf encode/decode utilities.
 * Follows the same hand-rolled pattern as adapters/aggrid/src/proto-utils.ts.
 */

const TEXT_ENCODER = new TextEncoder();
const TEXT_DECODER = new TextDecoder();

// ── Wire-level primitives ──────────────────────────────────

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
  out.push(...encodeTag(1, 0), ...encodeInt32(row1));
  out.push(...encodeTag(2, 0), ...encodeInt32(col1));
  out.push(...encodeTag(3, 0), ...encodeInt32(row2));
  out.push(...encodeTag(4, 0), ...encodeInt32(col2));
  return out;
}

export interface BorderArg {
  style?: number;   // BorderStyle enum
  color?: number;   // ARGB uint32
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
  if (border.style != null) out.push(...encodeTag(1, 0), ...encodeInt32(border.style));
  if (border.color != null) {
    out.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(border.color >>> 0)));
  }
  return out;
}

export function encodeBorders(borders: BordersArg): number[] {
  const out: number[] = [];
  if (borders.all) out.push(...encodeMessageField(1, encodeBorder(borders.all)));
  if (borders.top) out.push(...encodeMessageField(2, encodeBorder(borders.top)));
  if (borders.right) out.push(...encodeMessageField(3, encodeBorder(borders.right)));
  if (borders.bottom) out.push(...encodeMessageField(4, encodeBorder(borders.bottom)));
  if (borders.left) out.push(...encodeMessageField(5, encodeBorder(borders.left)));
  return out;
}

export function encodeHighlightStyle(style: HighlightStyleArg): number[] {
  const out: number[] = [];
  // HighlightStyle: background=1, foreground=2, borders=3, fill_handle=4, fill_handle_color=5
  if (style.background != null) {
    out.push(...encodeTag(1, 0), ...encodeVarintUnsigned(BigInt(style.background >>> 0)));
  }
  if (style.foreground != null) {
    out.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(style.foreground >>> 0)));
  }
  if (style.borders) {
    const b = encodeBorders(style.borders);
    if (b.length > 0) out.push(...encodeMessageField(3, b));
  }
  if (style.fillHandle != null) {
    out.push(...encodeTag(4, 0), ...encodeInt32(style.fillHandle));
  }
  if (style.fillHandleColor != null) {
    out.push(...encodeTag(5, 0), ...encodeVarintUnsigned(BigInt(style.fillHandleColor >>> 0)));
  }
  return out;
}

// ── Decoding primitives ────────────────────────────────────

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

// ── Edit Command encoders ──────────────────────────────────

export function encodeEditStart(args: {
  gridId: number;
  row: number;
  col: number;
  selectAll?: boolean;
  caretEnd?: boolean;
  seedText?: string;
  formulaMode?: boolean;
}): Uint8Array {
  // EditStart message
  const start: number[] = [];
  // EditStart.row = 1
  start.push(...encodeTag(1, 0), ...encodeInt32(args.row));
  // EditStart.col = 2
  start.push(...encodeTag(2, 0), ...encodeInt32(args.col));
  if (args.selectAll != null) {
    // EditStart.select_all = 3
    start.push(...encodeTag(3, 0), ...encodeBool(args.selectAll));
  }
  if (args.caretEnd != null) {
    // EditStart.caret_end = 4
    start.push(...encodeTag(4, 0), ...encodeBool(args.caretEnd));
  }
  if (args.seedText != null) {
    // EditStart.seed_text = 5
    start.push(...encodeStringField(5, args.seedText));
  }
  if (args.formulaMode != null) {
    // EditStart.formula_mode = 6
    start.push(...encodeTag(6, 0), ...encodeBool(args.formulaMode));
  }

  // EditCommand wrapper
  const out: number[] = [];
  // EditCommand.grid_id = 1
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));
  // EditCommand.start = 2 (oneof)
  out.push(...encodeMessageField(2, start));

  return new Uint8Array(out);
}

export function encodeEditCommit(args: {
  gridId: number;
  text?: string;
}): Uint8Array {
  const commit: number[] = [];
  if (args.text != null) {
    // EditCommit.text = 1
    commit.push(...encodeStringField(1, args.text));
  }

  const out: number[] = [];
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));
  // EditCommand.commit = 3
  out.push(...encodeMessageField(3, commit));

  return new Uint8Array(out);
}

export function encodeEditCancel(gridId: number): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(1, 0), ...encodeInt64(gridId));
  // EditCommand.cancel = 4 (empty message)
  out.push(...encodeMessageField(4, []));
  return new Uint8Array(out);
}

export function encodeEditSetText(args: {
  gridId: number;
  text: string;
}): Uint8Array {
  const setText: number[] = [];
  // EditSetText.text = 1
  setText.push(...encodeStringField(1, args.text));

  const out: number[] = [];
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));
  // EditCommand.set_text = 5
  out.push(...encodeMessageField(5, setText));
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
    regionMsg.push(
      ...encodeMessageField(1, encodeCellRange(region.row1, region.col1, region.row2, region.col2)),
    );
    regionMsg.push(...encodeMessageField(2, encodeHighlightStyle(region.style)));
    if (region.refId != null) {
      regionMsg.push(...encodeTag(3, 0), ...encodeInt32(region.refId));
    }
    if (region.textStart != null) {
      regionMsg.push(...encodeTag(4, 0), ...encodeInt32(region.textStart));
    }
    if (region.textLength != null) {
      regionMsg.push(...encodeTag(5, 0), ...encodeInt32(region.textLength));
    }
    setHighlights.push(...encodeMessageField(1, regionMsg));
  }

  const out: number[] = [];
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));
  // EditCommand.set_highlights = 8
  out.push(...encodeMessageField(8, setHighlights));
  return new Uint8Array(out);
}

// ── Select encoder ─────────────────────────────────────────

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
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));
  // SelectRequest.active_row = 2
  out.push(...encodeTag(2, 0), ...encodeInt32(args.row));
  // SelectRequest.active_col = 3
  out.push(...encodeTag(3, 0), ...encodeInt32(args.col));
  for (const range of ranges) {
    out.push(...encodeMessageField(4, encodeCellRange(range.row1, range.col1, range.row2, range.col2)));
  }
  if (args.show != null) {
    // SelectRequest.show = 5
    out.push(...encodeTag(5, 0), ...encodeBool(args.show));
  }
  return new Uint8Array(out);
}

// ── UpdateCells encoder ────────────────────────────────────

export interface FontArg {
  family?: string;
  size?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  width?: number;
}

// Flat cell style interface — used by sheet adapter for internal cache/toggles.
// The encoder maps these flat fields to the nested proto CellStyle structure.
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
  borderTop?: number;        // BorderStyle enum
  borderRight?: number;
  borderBottom?: number;
  borderLeft?: number;
  borderTopColor?: number;   // ARGB uint32
  borderRightColor?: number;
  borderBottomColor?: number;
  borderLeftColor?: number;
  shrinkToFit?: boolean;
}

export function encodeFont(font: FontArg): number[] {
  const out: number[] = [];
  // Font: family=1, families=2, size=3, bold=4, italic=5, underline=6, strikethrough=7, width=8
  if (font.family != null) out.push(...encodeStringField(1, font.family));
  if (font.size != null) {
    const buf = new ArrayBuffer(4);
    new DataView(buf).setFloat32(0, font.size, true);
    out.push(...encodeTag(3, 5), ...new Uint8Array(buf));
  }
  if (font.bold != null) out.push(...encodeTag(4, 0), ...encodeBool(font.bold));
  if (font.italic != null) out.push(...encodeTag(5, 0), ...encodeBool(font.italic));
  if (font.underline != null) out.push(...encodeTag(6, 0), ...encodeBool(font.underline));
  if (font.strikethrough != null) out.push(...encodeTag(7, 0), ...encodeBool(font.strikethrough));
  if (font.width != null) {
    const buf = new ArrayBuffer(4);
    new DataView(buf).setFloat32(0, font.width, true);
    out.push(...encodeTag(8, 5), ...new Uint8Array(buf));
  }
  return out;
}

// Encodes flat CellStyleFields → nested proto CellStyle
// CellStyle: background=1, foreground=2, align=3, font=4, padding=5,
//            borders=6, text_effect=7, progress=8, progress_color=9, shrink_to_fit=10
function encodeCellStyle(style: CellStyleFields): number[] {
  const out: number[] = [];
  if (typeof style.backColor === "number") {
    out.push(...encodeTag(1, 0), ...encodeVarintUnsigned(BigInt(style.backColor >>> 0)));
  }
  if (typeof style.foreColor === "number") {
    out.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(style.foreColor >>> 0)));
  }
  if (typeof style.alignment === "number") {
    out.push(...encodeTag(3, 0), ...encodeInt32(style.alignment));
  }

  // Font: nest flat font* fields into Font message (field 4)
  const font: FontArg = {};
  if (typeof style.fontName === "string") font.family = style.fontName;
  if (typeof style.fontSize === "number") font.size = style.fontSize;
  if (typeof style.fontBold === "boolean") font.bold = style.fontBold;
  if (typeof style.fontItalic === "boolean") font.italic = style.fontItalic;
  if (typeof style.fontUnderline === "boolean") font.underline = style.fontUnderline;
  if (typeof style.fontStrikethrough === "boolean") font.strikethrough = style.fontStrikethrough;
  const fontBytes = encodeFont(font);
  if (fontBytes.length > 0) out.push(...encodeMessageField(4, fontBytes));

  // Borders: nest flat border* fields into Borders message (field 6)
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
  if (bordersBytes.length > 0) out.push(...encodeMessageField(6, bordersBytes));

  if (typeof style.shrinkToFit === "boolean") {
    out.push(...encodeTag(10, 0), ...encodeBool(style.shrinkToFit));
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
  // UpdateCellsRequest.grid_id = 1
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));

  for (const update of args.updates) {
    const cellUpdate: number[] = [];
    // CellUpdate.row = 1
    cellUpdate.push(...encodeTag(1, 0), ...encodeInt32(update.row));
    // CellUpdate.col = 2
    cellUpdate.push(...encodeTag(2, 0), ...encodeInt32(update.col));

    if (update.text != null) {
      // CellUpdate.value = 3 (CellValue message, text = 1)
      const cellValue: number[] = [];
      cellValue.push(...encodeStringField(1, update.text));
      cellUpdate.push(...encodeMessageField(3, cellValue));
    }

    if (update.style) {
      const style = encodeCellStyle(update.style);
      if (style.length > 0) {
        // CellUpdate.style = 4
        cellUpdate.push(...encodeMessageField(4, style));
      }
    }

    // UpdateCellsRequest.cells = 2
    out.push(...encodeMessageField(2, cellUpdate));
  }

  return new Uint8Array(out);
}

// ── InsertRows encoder ─────────────────────────────────────

export function encodeInsertRowsRequest(args: {
  gridId: number;
  index: number;
  count: number;
  text?: string[];
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));
  out.push(...encodeTag(2, 0), ...encodeInt32(args.index));
  out.push(...encodeTag(3, 0), ...encodeInt32(args.count));
  if (args.text) {
    for (const rowText of args.text) {
      out.push(...encodeStringField(4, rowText));
    }
  }
  return new Uint8Array(out);
}

// ── Selection state decoder ────────────────────────────────

export interface SelectionState {
  row: number;
  col: number;
  rowEnd: number;
  colEnd: number;
}

export function decodeSelectionState(data: Uint8Array): SelectionState {
  const out: SelectionState = { row: -1, col: -1, rowEnd: -1, colEnd: -1 };
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
      if (field === 1) out.row = n;
      if (field === 2) out.col = n;
      if (field === 3) out.rowEnd = n;
      if (field === 4) out.colEnd = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  if (out.rowEnd < 0) out.rowEnd = out.row;
  if (out.colEnd < 0) out.colEnd = out.col;
  return out;
}
