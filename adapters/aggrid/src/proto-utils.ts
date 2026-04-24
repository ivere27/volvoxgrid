import {
  AfterSortEventFields,
  AfterUserResizeEventFields,
  BorderFields,
  BordersFields,
  CellRangeFields,
  CellStyleFields,
  CellUpdateFields,
  CellValueFields,
  ColumnDataType,
  ColumnDefFields,
  DefineColumnsRequestFields,
  ExportResponseFields,
  FontFields,
  GridEventFields,
  LoadTableRequestFields,
  PaddingFields,
  SelectRequestFields,
  SelectionStateFields,
  UpdateCellsRequestFields,
} from "volvoxgrid/generated/volvoxgrid_ffi.js";

export interface SelectionState {
  row: number;
  col: number;
  rowEnd: number;
  colEnd: number;
  topRow: number;
  leftCol: number;
  bottomRow: number;
  rightCol: number;
  mouseRow: number;
  mouseCol: number;
}

export interface AfterSortPayload {
  col: number;
}

export interface AfterUserResizePayload {
  row: number;
  col: number;
}

export interface GridEventEnvelope {
  eventField: number;
  payload: Uint8Array;
}

const TEXT_ENCODER = new TextEncoder();

const GRID_EVENT_PAYLOAD_FIELDS: ReadonlySet<number> = new Set<number>(
  (Object.values(GridEventFields) as number[]).filter(
    (field) => field !== GridEventFields.grid_id && field !== GridEventFields.event_id,
  ),
);

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

function encodeInt64(value: number): number[] {
  return encodeVarintUnsigned(BigInt(Math.trunc(value)));
}

function encodeBool(value: boolean): number[] {
  return encodeVarintUnsigned(value ? 1n : 0n);
}

function encodeString(value: string): number[] {
  return Array.from(TEXT_ENCODER.encode(value));
}

function encodeBytes(value: Uint8Array): number[] {
  return Array.from(value);
}

function encodeDouble(value: number): number[] {
  const buf = new ArrayBuffer(8);
  const view = new DataView(buf);
  view.setFloat64(0, value, true);
  return Array.from(new Uint8Array(buf));
}

function encodeFloat(value: number): number[] {
  const buf = new ArrayBuffer(4);
  const view = new DataView(buf);
  view.setFloat32(0, value, true);
  return Array.from(new Uint8Array(buf));
}

function encodeMessageField(field: number, payload: number[]): number[] {
  return [
    ...encodeTag(field, 2),
    ...encodeVarintUnsigned(BigInt(payload.length)),
    ...payload,
  ];
}

function encodeStringField(field: number, value: string): number[] {
  const text = encodeString(value);
  return [
    ...encodeTag(field, 2),
    ...encodeVarintUnsigned(BigInt(text.length)),
    ...text,
  ];
}

interface FontArg {
  family?: string;
  size?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  stretch?: number;
}

interface BorderArg {
  style?: number;
  color?: number;
}

interface BordersArg {
  all?: BorderArg;
  top?: BorderArg;
  right?: BorderArg;
  bottom?: BorderArg;
  left?: BorderArg;
}

function encodeFont(font: FontArg): number[] {
  const out: number[] = [];
  if (font.family != null) out.push(...encodeStringField(FontFields.family, font.family));
  if (font.size != null) out.push(...encodeTag(FontFields.size, 5), ...encodeFloat(font.size));
  if (font.bold != null) out.push(...encodeTag(FontFields.bold, 0), ...encodeBool(font.bold));
  if (font.italic != null) out.push(...encodeTag(FontFields.italic, 0), ...encodeBool(font.italic));
  if (font.underline != null) out.push(...encodeTag(FontFields.underline, 0), ...encodeBool(font.underline));
  if (font.strikethrough != null) out.push(...encodeTag(FontFields.strikethrough, 0), ...encodeBool(font.strikethrough));
  if (font.stretch != null) out.push(...encodeTag(FontFields.stretch, 5), ...encodeFloat(font.stretch));
  return out;
}

function encodeBorder(border: BorderArg): number[] {
  const out: number[] = [];
  if (border.style != null) out.push(...encodeTag(BorderFields.style, 0), ...encodeInt32(border.style));
  if (border.color != null) {
    out.push(
      ...encodeTag(BorderFields.color, 0),
      ...encodeVarintUnsigned(BigInt(border.color >>> 0)),
    );
  }
  return out;
}

function encodeBorders(borders: BordersArg): number[] {
  const out: number[] = [];
  if (borders.all) out.push(...encodeMessageField(BordersFields.all, encodeBorder(borders.all)));
  if (borders.top) out.push(...encodeMessageField(BordersFields.top, encodeBorder(borders.top)));
  if (borders.right) out.push(...encodeMessageField(BordersFields.right, encodeBorder(borders.right)));
  if (borders.bottom) {
    out.push(...encodeMessageField(BordersFields.bottom, encodeBorder(borders.bottom)));
  }
  if (borders.left) out.push(...encodeMessageField(BordersFields.left, encodeBorder(borders.left)));
  return out;
}

function encodeCellValue(value: unknown): number[] {
  if (value == null) {
    return [];
  }
  if (typeof value === "string") {
    const text = encodeString(value);
    return [
      ...encodeTag(CellValueFields.text, 2),
      ...encodeVarintUnsigned(BigInt(text.length)),
      ...text,
    ];
  }
  if (typeof value === "number") {
    return [
      ...encodeTag(CellValueFields.number, 1),
      ...encodeDouble(value),
    ];
  }
  if (typeof value === "boolean") {
    return [
      ...encodeTag(CellValueFields.flag, 0),
      ...encodeBool(value),
    ];
  }
  if (value instanceof Uint8Array) {
    const bytes = encodeBytes(value);
    return [
      ...encodeTag(CellValueFields.raw, 2),
      ...encodeVarintUnsigned(BigInt(bytes.length)),
      ...bytes,
    ];
  }
  if (value instanceof Date) {
    return [
      ...encodeTag(CellValueFields.timestamp, 0),
      ...encodeInt64(value.getTime()),
    ];
  }
  return encodeCellValue(String(value));
}

export function encodeLoadTableRequest(args: {
  gridId: number;
  rows: number;
  cols: number;
  values: unknown[];
  atomic?: boolean;
}): Uint8Array {
  const out: number[] = [];
  const total = Math.max(0, args.rows) * Math.max(0, args.cols);

  out.push(...encodeTag(LoadTableRequestFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeTag(LoadTableRequestFields.rows, 0), ...encodeInt32(args.rows));
  out.push(...encodeTag(LoadTableRequestFields.cols, 0), ...encodeInt32(args.cols));

  for (let i = 0; i < total; i += 1) {
    const cell = encodeCellValue(args.values[i]);
    out.push(
      ...encodeTag(LoadTableRequestFields.values, 2),
      ...encodeVarintUnsigned(BigInt(cell.length)),
      ...cell,
    );
  }

  if (args.atomic) {
    out.push(...encodeTag(LoadTableRequestFields.atomic, 0), ...encodeBool(true));
  }

  return new Uint8Array(out);
}

function encodeCellRange(row1: number, col1: number, row2: number, col2: number): number[] {
  const out: number[] = [];
  out.push(...encodeTag(CellRangeFields.row1, 0), ...encodeInt32(row1));
  out.push(...encodeTag(CellRangeFields.col1, 0), ...encodeInt32(col1));
  out.push(...encodeTag(CellRangeFields.row2, 0), ...encodeInt32(row2));
  out.push(...encodeTag(CellRangeFields.col2, 0), ...encodeInt32(col2));
  return out;
}

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
  out.push(...encodeTag(SelectRequestFields.grid_id, 0), ...encodeInt64(args.gridId));
  out.push(...encodeTag(SelectRequestFields.active_row, 0), ...encodeInt32(args.row));
  out.push(...encodeTag(SelectRequestFields.active_col, 0), ...encodeInt32(args.col));
  out.push(
    ...encodeMessageField(
      SelectRequestFields.ranges,
      encodeCellRange(args.row, args.col, rowEnd, colEnd),
    ),
  );
  if (args.show != null) {
    out.push(...encodeTag(SelectRequestFields.show, 0), ...encodeBool(args.show));
  }
  return new Uint8Array(out);
}

export function encodeDefineBooleanColumnsRequest(args: {
  gridId: number;
  columnIndices: number[];
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(DefineColumnsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const idx of args.columnIndices) {
    const colDef: number[] = [];
    colDef.push(...encodeTag(ColumnDefFields.index, 0), ...encodeInt32(idx));
    colDef.push(
      ...encodeTag(ColumnDefFields.data_type, 0),
      ...encodeInt32(ColumnDataType.COLUMN_DATA_BOOLEAN),
    );

    out.push(
      ...encodeTag(DefineColumnsRequestFields.columns, 2),
      ...encodeVarintUnsigned(BigInt(colDef.length)),
      ...colDef,
    );
  }

  return new Uint8Array(out);
}

export function encodeDefineColumnAlignmentsRequest(args: {
  gridId: number;
  columnIndices: number[];
  alignment: number;
  fixedAlignment?: number;
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(DefineColumnsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const idx of args.columnIndices) {
    const colDef: number[] = [];
    colDef.push(...encodeTag(ColumnDefFields.index, 0), ...encodeInt32(idx));
    colDef.push(...encodeTag(ColumnDefFields.align, 0), ...encodeInt32(args.alignment));
    if (typeof args.fixedAlignment === "number") {
      colDef.push(
        ...encodeTag(ColumnDefFields.fixed_align, 0),
        ...encodeInt32(args.fixedAlignment),
      );
    }

    out.push(
      ...encodeTag(DefineColumnsRequestFields.columns, 2),
      ...encodeVarintUnsigned(BigInt(colDef.length)),
      ...colDef,
    );
  }

  return new Uint8Array(out);
}

export function encodeDefineColumnSortTypesRequest(args: {
  gridId: number;
  columns: Array<{ index: number; sortType: number }>;
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(DefineColumnsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const column of args.columns) {
    const colDef: number[] = [];
    colDef.push(...encodeTag(ColumnDefFields.index, 0), ...encodeInt32(column.index));
    colDef.push(...encodeTag(ColumnDefFields.sort_type, 0), ...encodeInt32(column.sortType));

    out.push(
      ...encodeTag(DefineColumnsRequestFields.columns, 2),
      ...encodeVarintUnsigned(BigInt(colDef.length)),
      ...colDef,
    );
  }

  return new Uint8Array(out);
}

export function encodeUpdateCheckedCellsRequest(args: {
  gridId: number;
  updates: Array<{ row: number; col: number; checked: number }>;
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(UpdateCellsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const update of args.updates) {
    const cellUpdate: number[] = [];
    cellUpdate.push(...encodeTag(CellUpdateFields.row, 0), ...encodeInt32(update.row));
    cellUpdate.push(...encodeTag(CellUpdateFields.col, 0), ...encodeInt32(update.col));
    cellUpdate.push(...encodeTag(CellUpdateFields.checked, 0), ...encodeInt32(update.checked));

    out.push(
      ...encodeTag(UpdateCellsRequestFields.cells, 2),
      ...encodeVarintUnsigned(BigInt(cellUpdate.length)),
      ...cellUpdate,
    );
  }

  return new Uint8Array(out);
}

export function encodeUpdateBoldCellsRequest(args: {
  gridId: number;
  updates: Array<{ row: number; col: number; bold: boolean }>;
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(UpdateCellsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const update of args.updates) {
    const style: number[] = [];
    const font = encodeFont({ bold: update.bold });
    if (font.length > 0) {
      style.push(...encodeMessageField(CellStyleFields.font, font));
    }

    const cellUpdate: number[] = [];
    cellUpdate.push(...encodeTag(CellUpdateFields.row, 0), ...encodeInt32(update.row));
    cellUpdate.push(...encodeTag(CellUpdateFields.col, 0), ...encodeInt32(update.col));
    cellUpdate.push(
      ...encodeTag(CellUpdateFields.style, 2),
      ...encodeVarintUnsigned(BigInt(style.length)),
      ...style,
    );

    out.push(
      ...encodeTag(UpdateCellsRequestFields.cells, 2),
      ...encodeVarintUnsigned(BigInt(cellUpdate.length)),
      ...cellUpdate,
    );
  }

  return new Uint8Array(out);
}

export interface CellPaddingUpdate {
  row: number;
  col: number;
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export function encodeUpdateCellPaddingRequest(args: {
  gridId: number;
  updates: CellPaddingUpdate[];
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(UpdateCellsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const update of args.updates) {
    const padding: number[] = [];
    padding.push(...encodeTag(PaddingFields.left, 0), ...encodeInt32(update.left));
    padding.push(...encodeTag(PaddingFields.top, 0), ...encodeInt32(update.top));
    padding.push(...encodeTag(PaddingFields.right, 0), ...encodeInt32(update.right));
    padding.push(...encodeTag(PaddingFields.bottom, 0), ...encodeInt32(update.bottom));

    const style: number[] = [];
    style.push(...encodeMessageField(CellStyleFields.padding, padding));

    const cellUpdate: number[] = [];
    cellUpdate.push(...encodeTag(CellUpdateFields.row, 0), ...encodeInt32(update.row));
    cellUpdate.push(...encodeTag(CellUpdateFields.col, 0), ...encodeInt32(update.col));
    cellUpdate.push(
      ...encodeTag(CellUpdateFields.style, 2),
      ...encodeVarintUnsigned(BigInt(style.length)),
      ...style,
    );

    out.push(
      ...encodeTag(UpdateCellsRequestFields.cells, 2),
      ...encodeVarintUnsigned(BigInt(cellUpdate.length)),
      ...cellUpdate,
    );
  }

  return new Uint8Array(out);
}

export interface CellBorderUpdate {
  row: number;
  col: number;
  left?: number;
  top?: number;
  right?: number;
  bottom?: number;
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
}

export function encodeUpdateCellBordersRequest(args: {
  gridId: number;
  updates: CellBorderUpdate[];
}): Uint8Array {
  const out: number[] = [];
  out.push(...encodeTag(UpdateCellsRequestFields.grid_id, 0), ...encodeInt64(args.gridId));

  for (const update of args.updates) {
    const style: number[] = [];
    if (
      typeof update.left === "number"
      || typeof update.top === "number"
      || typeof update.right === "number"
      || typeof update.bottom === "number"
    ) {
      const padding: number[] = [];
      if (typeof update.left === "number") {
        padding.push(...encodeTag(PaddingFields.left, 0), ...encodeInt32(update.left));
      }
      if (typeof update.top === "number") {
        padding.push(...encodeTag(PaddingFields.top, 0), ...encodeInt32(update.top));
      }
      if (typeof update.right === "number") {
        padding.push(...encodeTag(PaddingFields.right, 0), ...encodeInt32(update.right));
      }
      if (typeof update.bottom === "number") {
        padding.push(...encodeTag(PaddingFields.bottom, 0), ...encodeInt32(update.bottom));
      }
      if (padding.length > 0) {
        style.push(...encodeMessageField(CellStyleFields.padding, padding));
      }
    }
    const borders: BordersArg = {};
    if (typeof update.border === "number" || typeof update.borderColor === "number") {
      borders.all = {
        style: update.border,
        color: update.borderColor,
      };
    }
    if (typeof update.borderTop === "number" || typeof update.borderTopColor === "number") {
      borders.top = {
        style: update.borderTop,
        color: update.borderTopColor,
      };
    }
    if (typeof update.borderRight === "number" || typeof update.borderRightColor === "number") {
      borders.right = {
        style: update.borderRight,
        color: update.borderRightColor,
      };
    }
    if (typeof update.borderBottom === "number" || typeof update.borderBottomColor === "number") {
      borders.bottom = {
        style: update.borderBottom,
        color: update.borderBottomColor,
      };
    }
    if (typeof update.borderLeft === "number" || typeof update.borderLeftColor === "number") {
      borders.left = {
        style: update.borderLeft,
        color: update.borderLeftColor,
      };
    }
    const bordersPayload = encodeBorders(borders);
    if (bordersPayload.length > 0) {
      style.push(...encodeMessageField(CellStyleFields.borders, bordersPayload));
    }

    if (style.length === 0) {
      continue;
    }

    const cellUpdate: number[] = [];
    cellUpdate.push(...encodeTag(CellUpdateFields.row, 0), ...encodeInt32(update.row));
    cellUpdate.push(...encodeTag(CellUpdateFields.col, 0), ...encodeInt32(update.col));
    cellUpdate.push(
      ...encodeTag(CellUpdateFields.style, 2),
      ...encodeVarintUnsigned(BigInt(style.length)),
      ...style,
    );

    out.push(
      ...encodeTag(UpdateCellsRequestFields.cells, 2),
      ...encodeVarintUnsigned(BigInt(cellUpdate.length)),
      ...cellUpdate,
    );
  }

  return new Uint8Array(out);
}

function readVarint(data: Uint8Array, offset: number): { value: bigint; next: number } {
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
    if (shift > 70n) {
      break;
    }
  }
  return { value: 0n, next: data.length };
}

function skipField(data: Uint8Array, offset: number, wireType: number): number {
  if (wireType === 0) {
    return readVarint(data, offset).next;
  }
  if (wireType === 1) {
    return Math.min(data.length, offset + 8);
  }
  if (wireType === 2) {
    const length = readVarint(data, offset);
    const n = Number(length.value);
    if (!Number.isFinite(n) || n < 0) {
      return data.length;
    }
    return Math.min(data.length, length.next + n);
  }
  if (wireType === 5) {
    return Math.min(data.length, offset + 4);
  }
  return data.length;
}

function asInt32(value: bigint): number {
  return Number(BigInt.asIntN(32, value));
}

interface CellRangePayload {
  row1: number;
  col1: number;
  row2: number;
  col2: number;
}

function decodeCellRange(data: Uint8Array): CellRangePayload {
  const out: CellRangePayload = { row1: -1, col1: -1, row2: -1, col2: -1 };
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
      if (field === CellRangeFields.row1) out.row1 = n;
      if (field === CellRangeFields.col1) out.col1 = n;
      if (field === CellRangeFields.row2) out.row2 = n;
      if (field === CellRangeFields.col2) out.col2 = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return out;
}

export function decodeSelectionState(data: Uint8Array): SelectionState {
  const out: SelectionState = {
    row: -1,
    col: -1,
    rowEnd: -1,
    colEnd: -1,
    topRow: 0,
    leftCol: 0,
    bottomRow: -1,
    rightCol: -1,
    mouseRow: -1,
    mouseCol: -1,
  };
  let lastRange: CellRangePayload | null = null;
  let hasRanges = false;
  const scalarByField: Partial<Record<number, number>> = {};

  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);

    if (field === SelectionStateFields.ranges && wire === 2) {
      const length = readVarint(data, offset);
      const n = Number(length.value);
      if (!Number.isFinite(n) || n < 0) {
        break;
      }
      const start = length.next;
      const end = Math.min(data.length, start + n);
      lastRange = decodeCellRange(data.slice(start, end));
      hasRanges = true;
      offset = end;
      continue;
    }

    if (wire === 0) {
      const value = readVarint(data, offset);
      offset = value.next;
      const n = asInt32(value.value);
      scalarByField[field] = n;
      continue;
    }

    offset = skipField(data, offset, wire);
  }

  if (typeof scalarByField[SelectionStateFields.active_row] === "number") {
    out.row = scalarByField[SelectionStateFields.active_row] ?? out.row;
  }
  if (typeof scalarByField[SelectionStateFields.active_col] === "number") {
    out.col = scalarByField[SelectionStateFields.active_col] ?? out.col;
  }

  if (hasRanges) {
    if (typeof scalarByField[SelectionStateFields.top_row] === "number") {
      out.topRow = scalarByField[SelectionStateFields.top_row] ?? out.topRow;
    }
    if (typeof scalarByField[SelectionStateFields.left_col] === "number") {
      out.leftCol = scalarByField[SelectionStateFields.left_col] ?? out.leftCol;
    }
    if (typeof scalarByField[SelectionStateFields.bottom_row] === "number") {
      out.bottomRow = scalarByField[SelectionStateFields.bottom_row] ?? out.bottomRow;
    }
    if (typeof scalarByField[SelectionStateFields.right_col] === "number") {
      out.rightCol = scalarByField[SelectionStateFields.right_col] ?? out.rightCol;
    }
    if (typeof scalarByField[SelectionStateFields.mouse_row] === "number") {
      out.mouseRow = scalarByField[SelectionStateFields.mouse_row] ?? out.mouseRow;
    }
    if (typeof scalarByField[SelectionStateFields.mouse_col] === "number") {
      out.mouseCol = scalarByField[SelectionStateFields.mouse_col] ?? out.mouseCol;
    }
  } else {
    // Legacy flat selection payloads used rowEnd/colEnd instead of ranges.
    if (typeof scalarByField[3] === "number") out.rowEnd = scalarByField[3];
    if (typeof scalarByField[4] === "number") out.colEnd = scalarByField[4];
    if (typeof scalarByField[5] === "number") out.topRow = scalarByField[5];
    if (typeof scalarByField[6] === "number") out.leftCol = scalarByField[6];
    if (typeof scalarByField[7] === "number") out.bottomRow = scalarByField[7];
    if (typeof scalarByField[8] === "number") out.rightCol = scalarByField[8];
    if (typeof scalarByField[9] === "number") out.mouseRow = scalarByField[9];
    if (typeof scalarByField[10] === "number") out.mouseCol = scalarByField[10];
  }

  if (out.rowEnd < 0) {
    out.rowEnd = out.row;
  }
  if (out.colEnd < 0) {
    out.colEnd = out.col;
  }
  if (lastRange != null) {
    if (out.row === lastRange.row1 && out.col === lastRange.col1) {
      out.rowEnd = lastRange.row2;
      out.colEnd = lastRange.col2;
    } else if (out.row === lastRange.row2 && out.col === lastRange.col2) {
      out.rowEnd = lastRange.row1;
      out.colEnd = lastRange.col1;
    } else {
      out.rowEnd = lastRange.row2;
      out.colEnd = lastRange.col2;
    }
  }

  return out;
}

export function decodeExportCsv(data: Uint8Array): string {
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);

    if (field === ExportResponseFields.data && wire === 2) {
      const length = readVarint(data, offset);
      const n = Number(length.value);
      if (!Number.isFinite(n) || n < 0) {
        return "";
      }
      const start = length.next;
      const end = Math.min(data.length, start + n);
      return new TextDecoder().decode(data.slice(start, end));
    }

    offset = skipField(data, offset, wire);
  }
  return "";
}

export function decodeGridEventEnvelope(data: Uint8Array): GridEventEnvelope | null {
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);

    if (wire === 2 && GRID_EVENT_PAYLOAD_FIELDS.has(field)) {
      const length = readVarint(data, offset);
      const n = Number(length.value);
      if (!Number.isFinite(n) || n < 0) {
        return null;
      }
      const start = length.next;
      const end = Math.min(data.length, start + n);
      return {
        eventField: field,
        payload: data.slice(start, end),
      };
    }

    offset = skipField(data, offset, wire);
  }
  return null;
}

export function decodeAfterSortPayload(data: Uint8Array): AfterSortPayload {
  let col = -1;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === AfterSortEventFields.col && wire === 0) {
      const value = readVarint(data, offset);
      col = asInt32(value.value);
      offset = value.next;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { col };
}

export function decodeAfterUserResizePayload(data: Uint8Array): AfterUserResizePayload {
  let row = -1;
  let col = -1;
  let offset = 0;
  while (offset < data.length) {
    const tag = readVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const value = readVarint(data, offset);
      const n = asInt32(value.value);
      offset = value.next;
      if (field === AfterUserResizeEventFields.row) row = n;
      if (field === AfterUserResizeEventFields.col) col = n;
      continue;
    }
    offset = skipField(data, offset, wire);
  }
  return { row, col };
}
