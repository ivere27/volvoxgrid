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

export interface HighlightStyleArg {
  backColor?: number;
  foreColor?: number;
  border?: number;
  borderColor?: number;
  borderTop?: number;
  borderRight?: number;
  borderBottom?: number;
  borderLeft?: number;
  borderTopColor?: number;
  borderRightColor?: number;
  borderBottomColor?: number;
  borderLeftColor?: number;
  fillHandle?: number;
  fillHandleColor?: number;
}

export function encodeHighlightStyle(style: HighlightStyleArg): number[] {
  const out: number[] = [];
  if (style.backColor != null) {
    out.push(...encodeTag(1, 0), ...encodeVarintUnsigned(BigInt(style.backColor >>> 0)));
  }
  if (style.foreColor != null) {
    out.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(style.foreColor >>> 0)));
  }
  if (style.border != null) {
    out.push(...encodeTag(3, 0), ...encodeInt32(style.border));
  }
  if (style.borderColor != null) {
    out.push(...encodeTag(4, 0), ...encodeVarintUnsigned(BigInt(style.borderColor >>> 0)));
  }
  if (style.borderTop != null) {
    out.push(...encodeTag(5, 0), ...encodeInt32(style.borderTop));
  }
  if (style.borderRight != null) {
    out.push(...encodeTag(6, 0), ...encodeInt32(style.borderRight));
  }
  if (style.borderBottom != null) {
    out.push(...encodeTag(7, 0), ...encodeInt32(style.borderBottom));
  }
  if (style.borderLeft != null) {
    out.push(...encodeTag(8, 0), ...encodeInt32(style.borderLeft));
  }
  if (style.borderTopColor != null) {
    out.push(...encodeTag(9, 0), ...encodeVarintUnsigned(BigInt(style.borderTopColor >>> 0)));
  }
  if (style.borderRightColor != null) {
    out.push(...encodeTag(10, 0), ...encodeVarintUnsigned(BigInt(style.borderRightColor >>> 0)));
  }
  if (style.borderBottomColor != null) {
    out.push(...encodeTag(11, 0), ...encodeVarintUnsigned(BigInt(style.borderBottomColor >>> 0)));
  }
  if (style.borderLeftColor != null) {
    out.push(...encodeTag(12, 0), ...encodeVarintUnsigned(BigInt(style.borderLeftColor >>> 0)));
  }
  if (style.fillHandle != null) {
    out.push(...encodeTag(13, 0), ...encodeInt32(style.fillHandle));
  }
  if (style.fillHandleColor != null) {
    out.push(...encodeTag(14, 0), ...encodeVarintUnsigned(BigInt(style.fillHandleColor >>> 0)));
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
  show?: boolean;
}): Uint8Array {
  const out: number[] = [];
  const rowEnd = args.rowEnd ?? args.row;
  const colEnd = args.colEnd ?? args.col;
  out.push(...encodeTag(1, 0), ...encodeInt64(args.gridId));
  // SelectRequest.active_row = 2
  out.push(...encodeTag(2, 0), ...encodeInt32(args.row));
  // SelectRequest.active_col = 3
  out.push(...encodeTag(3, 0), ...encodeInt32(args.col));
  // SelectRequest.ranges = 4 (single range compatibility)
  out.push(...encodeMessageField(4, encodeCellRange(args.row, args.col, rowEnd, colEnd)));
  if (args.show != null) {
    // SelectRequest.show = 5
    out.push(...encodeTag(5, 0), ...encodeBool(args.show));
  }
  return new Uint8Array(out);
}

// ── UpdateCells encoder ────────────────────────────────────

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
  // Per-edge borders (tags 17-24 in CellStyleOverride)
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

function encodeStyleOverride(style: CellStyleFields): number[] {
  const out: number[] = [];
  if (typeof style.backColor === "number") {
    // CellStyleOverride.back_color = 1
    out.push(...encodeTag(1, 0), ...encodeVarintUnsigned(BigInt(style.backColor >>> 0)));
  }
  if (typeof style.foreColor === "number") {
    // CellStyleOverride.fore_color = 2
    out.push(...encodeTag(2, 0), ...encodeVarintUnsigned(BigInt(style.foreColor >>> 0)));
  }
  if (typeof style.alignment === "number") {
    // CellStyleOverride.alignment = 3
    out.push(...encodeTag(3, 0), ...encodeInt32(style.alignment));
  }
  if (typeof style.fontName === "string") {
    // CellStyleOverride.font_name = 5
    out.push(...encodeStringField(5, style.fontName));
  }
  if (typeof style.fontSize === "number") {
    // CellStyleOverride.font_size = 6 (float, wire type 5 = fixed32)
    const buf = new ArrayBuffer(4);
    new DataView(buf).setFloat32(0, style.fontSize, true);
    const bytes = new Uint8Array(buf);
    out.push(...encodeTag(6, 5), ...bytes);
  }
  if (typeof style.fontBold === "boolean") {
    // CellStyleOverride.font_bold = 7
    out.push(...encodeTag(7, 0), ...encodeBool(style.fontBold));
  }
  if (typeof style.fontItalic === "boolean") {
    // CellStyleOverride.font_italic = 8
    out.push(...encodeTag(8, 0), ...encodeBool(style.fontItalic));
  }
  if (typeof style.fontUnderline === "boolean") {
    // CellStyleOverride.font_underline = 9
    out.push(...encodeTag(9, 0), ...encodeBool(style.fontUnderline));
  }
  if (typeof style.fontStrikethrough === "boolean") {
    // CellStyleOverride.font_strikethrough = 10
    out.push(...encodeTag(10, 0), ...encodeBool(style.fontStrikethrough));
  }
  // Border styles (tags 17-20)
  if (typeof style.borderTop === "number") {
    out.push(...encodeTag(17, 0), ...encodeInt32(style.borderTop));
  }
  if (typeof style.borderRight === "number") {
    out.push(...encodeTag(18, 0), ...encodeInt32(style.borderRight));
  }
  if (typeof style.borderBottom === "number") {
    out.push(...encodeTag(19, 0), ...encodeInt32(style.borderBottom));
  }
  if (typeof style.borderLeft === "number") {
    out.push(...encodeTag(20, 0), ...encodeInt32(style.borderLeft));
  }
  // Border colors (tags 21-24)
  if (typeof style.borderTopColor === "number") {
    out.push(...encodeTag(21, 0), ...encodeVarintUnsigned(BigInt(style.borderTopColor >>> 0)));
  }
  if (typeof style.borderRightColor === "number") {
    out.push(...encodeTag(22, 0), ...encodeVarintUnsigned(BigInt(style.borderRightColor >>> 0)));
  }
  if (typeof style.borderBottomColor === "number") {
    out.push(...encodeTag(23, 0), ...encodeVarintUnsigned(BigInt(style.borderBottomColor >>> 0)));
  }
  if (typeof style.borderLeftColor === "number") {
    out.push(...encodeTag(24, 0), ...encodeVarintUnsigned(BigInt(style.borderLeftColor >>> 0)));
  }
  if (typeof style.shrinkToFit === "boolean") {
    // CellStyleOverride.shrink_to_fit = 25
    out.push(...encodeTag(25, 0), ...encodeBool(style.shrinkToFit));
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
      const style = encodeStyleOverride(update.style);
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
