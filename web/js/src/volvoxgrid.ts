/**
 * VolvoxGrid - High-performance pixel-rendering datagrid for the web.
 *
 * Wraps the Rust VolvoxGrid engine compiled to WebAssembly.  All grid state
 * lives inside WASM memory; this class manages the render loop, the
 * HTML canvas, and event forwarding.
 */
export interface VolvoxGridCellRange {
  row1: number;
  col1: number;
  row2: number;
  col2: number;
}

export interface VolvoxGridCellTextEntry {
  row: number;
  col: number;
  text: string;
}

export interface VolvoxGridSelection {
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
  ranges: VolvoxGridCellRange[];
}

export interface VolvoxGridNodeInfo {
  row: number;
  level: number;
  isExpanded: boolean;
  childCount: number;
  parentRow: number;
  firstChild: number;
  lastChild: number;
}

export interface VolvoxGridBeforeEditDetails {
  eventId: bigint;
  rawEvent: Uint8Array;
  row: number;
  col: number;
  cancel: boolean;
}

export interface VolvoxGridCellEditValidatingDetails {
  eventId: bigint;
  rawEvent: Uint8Array;
  row: number;
  col: number;
  editText: string;
  cancel: boolean;
}

export interface VolvoxGridBeforeSortDetails {
  eventId: bigint;
  rawEvent: Uint8Array;
  col: number;
  cancel: boolean;
}

export interface VolvoxGridHeaderFeatures {
  sort?: boolean;
  reorder?: boolean;
  chooser?: boolean;
}

export interface VolvoxGridResizePolicy {
  columns?: boolean;
  rows?: boolean;
  uniform?: boolean;
}

export interface VolvoxGridFreezePolicy {
  columns?: boolean;
  rows?: boolean;
}

export interface VolvoxGridPadding {
  left?: number;
  top?: number;
  right?: number;
  bottom?: number;
}

export type VolvoxGridCellPadding = VolvoxGridPadding;

export interface VolvoxGridFont {
  family?: string;
  families?: string[];
  size?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  width?: number;
}

export interface VolvoxGridBorder {
  style?: number;
  colorArgb?: number;
}

export interface VolvoxGridBorders {
  all?: VolvoxGridBorder;
  top?: VolvoxGridBorder;
  right?: VolvoxGridBorder;
  bottom?: VolvoxGridBorder;
  left?: VolvoxGridBorder;
}

export interface VolvoxGridCellStyle {
  background?: number;
  foreground?: number;
  align?: number;
  font?: VolvoxGridFont;
  padding?: VolvoxGridPadding;
  borders?: VolvoxGridBorders;
  textEffect?: number;
  progress?: number;
  progressColor?: number;
  shrinkToFit?: boolean;
}

export type VolvoxGridHeaderMarkHeight =
  | { mode: "ratio"; value: number }
  | { mode: "px"; value: number };

export interface VolvoxGridHeaderSeparator {
  enabled?: boolean;
  colorArgb?: number;
  widthPx?: number;
  height?: VolvoxGridHeaderMarkHeight;
  skipMerged?: boolean;
}

export type VolvoxGridHeaderSeparatorStyle = VolvoxGridHeaderSeparator;

export interface VolvoxGridHeaderResizeHandle {
  enabled?: boolean;
  colorArgb?: number;
  widthPx?: number;
  height?: VolvoxGridHeaderMarkHeight;
  hitWidthPx?: number;
  showOnlyWhenResizable?: boolean;
}

export type VolvoxGridHeaderResizeHandleStyle = VolvoxGridHeaderResizeHandle;

export interface VolvoxGridIconSlots {
  sortAscending?: string;
  sortDescending?: string;
  sortNone?: string;
  treeExpanded?: string;
  treeCollapsed?: string;
  menu?: string;
  filter?: string;
  filterActive?: string;
  columns?: string;
  dragHandle?: string;
  checkboxChecked?: string;
  checkboxUnchecked?: string;
  checkboxIndeterminate?: string;
}

export type VolvoxGridIconThemeSlots = VolvoxGridIconSlots;

export type VolvoxGridIconSlotName = keyof VolvoxGridIconSlots;

export interface VolvoxGridIconSourceNone {
  kind: "none";
}

export interface VolvoxGridIconSourceText {
  kind: "text";
  text: string;
}

export interface VolvoxGridIconSourceImage {
  kind: "image";
  format?: "png";
  data: Uint8Array;
}

export type VolvoxGridIconSource =
  | VolvoxGridIconSourceNone
  | VolvoxGridIconSourceText
  | VolvoxGridIconSourceImage;

export type VolvoxGridIconAlign =
  | "inlineEnd"
  | "inlineStart"
  | "start"
  | "end"
  | "center";

export interface VolvoxGridIconLayout {
  align?: VolvoxGridIconAlign;
  gapPx?: number;
}

export interface VolvoxGridIconTextStyle {
  fontName?: string;
  fontNames?: string[];
  fontSize?: number;
  bold?: boolean;
  italic?: boolean;
  colorArgb?: number;
}

export interface VolvoxGridIconSpec {
  source?: VolvoxGridIconSource;
  textStyle?: VolvoxGridIconTextStyle;
  layout?: VolvoxGridIconLayout;
}

export interface VolvoxGridIconThemeDefaults {
  textStyle?: VolvoxGridIconTextStyle;
  layout?: VolvoxGridIconLayout;
}

export interface VolvoxGridIconTheme {
  defaults?: VolvoxGridIconThemeDefaults;
  slots: Partial<Record<VolvoxGridIconSlotName, VolvoxGridIconSpec>>;
}

type ResolvedHeaderSeparatorStyle = {
  enabled: boolean;
  colorArgb: number;
  widthPx: number;
  height: VolvoxGridHeaderMarkHeight;
  skipMerged: boolean;
};

type ResolvedHeaderResizeHandleStyle = {
  enabled: boolean;
  colorArgb: number;
  widthPx: number;
  height: VolvoxGridHeaderMarkHeight;
  hitWidthPx: number;
  showOnlyWhenResizable: boolean;
};

const DEFAULT_HEADER_SEPARATOR_STYLE: ResolvedHeaderSeparatorStyle = {
  enabled: false,
  colorArgb: 0xffc9d2de,
  widthPx: 1,
  height: { mode: "ratio", value: 0.5 },
  skipMerged: true,
};

const DEFAULT_HEADER_RESIZE_HANDLE_STYLE: ResolvedHeaderResizeHandleStyle = {
  enabled: false,
  colorArgb: 0xffc9d2de,
  widthPx: 1,
  height: { mode: "ratio", value: 0.5 },
  hitWidthPx: 6,
  showOnlyWhenResizable: true,
};

const ICON_THEME_SLOT_META: Array<{
  name: VolvoxGridIconSlotName;
  slotId: number;
  pictureApi:
    | "sort_ascending"
    | "sort_descending"
    | "tree_open"
    | "tree_closed"
    | "checkbox_checked"
    | "checkbox_unchecked"
    | "checkbox_indeterminate"
    | null;
}> = [
  { name: "sortAscending", slotId: 1, pictureApi: "sort_ascending" },
  { name: "sortDescending", slotId: 2, pictureApi: "sort_descending" },
  { name: "sortNone", slotId: 3, pictureApi: null },
  { name: "treeExpanded", slotId: 4, pictureApi: "tree_open" },
  { name: "treeCollapsed", slotId: 5, pictureApi: "tree_closed" },
  { name: "menu", slotId: 6, pictureApi: null },
  { name: "filter", slotId: 7, pictureApi: null },
  { name: "filterActive", slotId: 8, pictureApi: null },
  { name: "columns", slotId: 9, pictureApi: null },
  { name: "dragHandle", slotId: 10, pictureApi: null },
  { name: "checkboxChecked", slotId: 11, pictureApi: "checkbox_checked" },
  { name: "checkboxUnchecked", slotId: 12, pictureApi: "checkbox_unchecked" },
  { name: "checkboxIndeterminate", slotId: 13, pictureApi: "checkbox_indeterminate" },
];

const ICON_THEME_SLOT_BY_NAME = new Map<VolvoxGridIconSlotName, {
  slotId: number;
  pictureApi:
    | "sort_ascending"
    | "sort_descending"
    | "tree_open"
    | "tree_closed"
    | "checkbox_checked"
    | "checkbox_unchecked"
    | "checkbox_indeterminate"
    | null;
}>(ICON_THEME_SLOT_META.map((slot) => [slot.name, { slotId: slot.slotId, pictureApi: slot.pictureApi }]));

const ICON_ALIGN_TO_WASM = new Map<VolvoxGridIconAlign, number>([
  ["inlineEnd", 0],
  ["inlineStart", 1],
  ["start", 2],
  ["end", 3],
  ["center", 4],
]);

const PB_TEXT_ENCODER = new TextEncoder();
const PB_TEXT_DECODER = new TextDecoder();
const GRID_EVENT_BEFORE_EDIT = 8;
const GRID_EVENT_CELL_EDIT_VALIDATE = 11;
const GRID_EVENT_BEFORE_SORT = 23;
const STREAM_STATUS_DATA = 0;
const STREAM_STATUS_EOF = 1;
const STREAM_STATUS_PENDING = 2;
type StreamHandle = number | bigint;

function decodeSignedStatus(statusByte: number): number {
  return statusByte > 127 ? statusByte - 256 : statusByte;
}

function decodeFfiErrorPayload(payload: Uint8Array): {
  message: string;
  code: number;
  grpcCode: number;
} {
  let offset = 0;
  let code = 0;
  let grpcCode = 0;
  let message: string | null = null;
  while (offset < payload.length) {
    const tag = pbReadVarint(payload, offset);
    offset = tag.next;
    if (tag.value === 0n) {
      break;
    }
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 0) {
      const value = pbReadVarint(payload, offset);
      code = pbAsInt32(value.value);
      offset = value.next;
      continue;
    }
    if (field === 2 && wire === 2) {
      const len = pbReadVarint(payload, offset);
      const size = Number(len.value);
      offset = len.next;
      if (!Number.isFinite(size) || size < 0 || offset + size > payload.length) {
        break;
      }
      message = PB_TEXT_DECODER.decode(payload.subarray(offset, offset + size));
      offset += size;
      continue;
    }
    if (field === 3 && wire === 0) {
      const value = pbReadVarint(payload, offset);
      grpcCode = pbAsInt32(value.value);
      offset = value.next;
      continue;
    }
    offset = pbSkipField(payload, offset, wire);
  }
  if (message == null) {
    message = PB_TEXT_DECODER.decode(payload);
  }
  return { message, code, grpcCode };
}

function throwFfiErrorPayload(payload: Uint8Array): never {
  const decoded = decodeFfiErrorPayload(payload);
  const error = new Error(decoded.message || "FFI error") as Error & {
    code: number;
    grpcCode: number;
    payload: Uint8Array;
  };
  error.name = "FfiError";
  error.code = decoded.code;
  error.grpcCode = decoded.grpcCode;
  error.payload = payload.slice();
  throw error;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value != null && !Array.isArray(value);
}

function isPngSignature(data: Uint8Array): boolean {
  if (data.length < 8) {
    return false;
  }
  const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  for (let i = 0; i < sig.length; i += 1) {
    if (data[i] !== sig[i]) {
      return false;
    }
  }
  return true;
}

function assertIconTextStyle(value: unknown, path: string): asserts value is VolvoxGridIconTextStyle {
  if (!isPlainObject(value)) {
    throw new TypeError(`${path} must be an object`);
  }
  if (value.fontName != null && typeof value.fontName !== "string") {
    throw new TypeError(`${path}.fontName must be a string`);
  }
  if (value.fontNames != null) {
    if (!Array.isArray(value.fontNames)) {
      throw new TypeError(`${path}.fontNames must be an array of strings`);
    }
    for (let i = 0; i < value.fontNames.length; i += 1) {
      const name = value.fontNames[i];
      if (typeof name !== "string" || name.trim().length === 0) {
        throw new TypeError(`${path}.fontNames[${i}] must be a non-empty string`);
      }
    }
  }
  if (value.fontSize != null) {
    if (typeof value.fontSize !== "number" || !Number.isFinite(value.fontSize) || value.fontSize <= 0) {
      throw new TypeError(`${path}.fontSize must be a positive finite number`);
    }
  }
  if (value.bold != null && typeof value.bold !== "boolean") {
    throw new TypeError(`${path}.bold must be boolean`);
  }
  if (value.italic != null && typeof value.italic !== "boolean") {
    throw new TypeError(`${path}.italic must be boolean`);
  }
  if (value.colorArgb != null) {
    if (
      typeof value.colorArgb !== "number"
      || !Number.isFinite(value.colorArgb)
      || value.colorArgb < 0
      || value.colorArgb > 0xffffffff
    ) {
      throw new TypeError(`${path}.colorArgb must be a uint32 number`);
    }
  }
}

function assertIconLayout(value: unknown, path: string): asserts value is VolvoxGridIconLayout {
  if (!isPlainObject(value)) {
    throw new TypeError(`${path} must be an object`);
  }
  if (value.align != null) {
    if (typeof value.align !== "string" || !ICON_ALIGN_TO_WASM.has(value.align as VolvoxGridIconAlign)) {
      throw new TypeError(`${path}.align must be one of: inlineEnd, inlineStart, start, end, center`);
    }
  }
  if (value.gapPx != null) {
    if (
      typeof value.gapPx !== "number"
      || !Number.isFinite(value.gapPx)
      || value.gapPx < 0
    ) {
      throw new TypeError(`${path}.gapPx must be a non-negative finite number`);
    }
  }
}

function assertIconTheme(value: unknown): asserts value is VolvoxGridIconTheme {
  if (!isPlainObject(value)) {
    throw new TypeError("setIconTheme: theme must be an object");
  }
  if (value.defaults != null) {
    if (!isPlainObject(value.defaults)) {
      throw new TypeError("setIconTheme: theme.defaults must be an object");
    }
    if (value.defaults.textStyle != null) {
      assertIconTextStyle(value.defaults.textStyle, "setIconTheme: theme.defaults.textStyle");
    }
    if (value.defaults.layout != null) {
      assertIconLayout(value.defaults.layout, "setIconTheme: theme.defaults.layout");
    }
  }
  if (!isPlainObject(value.slots)) {
    throw new TypeError("setIconTheme: theme.slots must be an object");
  }
  for (const [rawSlot, rawSpec] of Object.entries(value.slots)) {
    if (!ICON_THEME_SLOT_BY_NAME.has(rawSlot as VolvoxGridIconSlotName)) {
      throw new TypeError(`setIconTheme: unknown slot '${rawSlot}'`);
    }
    if (!isPlainObject(rawSpec)) {
      throw new TypeError(`setIconTheme: slot '${rawSlot}' must be an object`);
    }
    const hasSource = rawSpec.source != null;
    if (hasSource) {
      if (!isPlainObject(rawSpec.source)) {
        throw new TypeError(`setIconTheme: slot '${rawSlot}' source must be an object`);
      }
      const source = rawSpec.source as Record<string, unknown>;
      const kind = source.kind;
      if (kind === "none") {
        // noop
      } else if (kind === "text") {
        if (typeof source.text !== "string" || source.text.trim().length === 0) {
          throw new TypeError(`setIconTheme: slot '${rawSlot}' text source requires non-empty text`);
        }
      } else if (kind === "image") {
        const format = source.format ?? "png";
        if (format !== "png") {
          throw new TypeError(`setIconTheme: slot '${rawSlot}' only supports png image format`);
        }
        if (!(source.data instanceof Uint8Array)) {
          throw new TypeError(`setIconTheme: slot '${rawSlot}' image source requires Uint8Array data`);
        }
        if (source.data.length === 0) {
          throw new TypeError(`setIconTheme: slot '${rawSlot}' image data must not be empty`);
        }
        if (!isPngSignature(source.data)) {
          throw new TypeError(`setIconTheme: slot '${rawSlot}' image data is not valid PNG bytes`);
        }
        const meta = ICON_THEME_SLOT_BY_NAME.get(rawSlot as VolvoxGridIconSlotName);
        if (meta?.pictureApi == null) {
          throw new TypeError(`setIconTheme: slot '${rawSlot}' does not support image source yet`);
        }
      } else {
        throw new TypeError(
          `setIconTheme: slot '${rawSlot}' source.kind must be 'none', 'text', or 'image'`,
        );
      }
    }

    if (rawSpec.textStyle != null) {
      assertIconTextStyle(rawSpec.textStyle, `setIconTheme: slot '${rawSlot}' textStyle`);
    }

    if (rawSpec.layout != null) {
      assertIconLayout(rawSpec.layout, `setIconTheme: slot '${rawSlot}' layout`);
    }

    if (rawSpec.paint != null) {
      throw new TypeError(`setIconTheme: slot '${rawSlot}' paint is not supported yet`);
    }
    if (!hasSource && rawSpec.textStyle == null && rawSpec.layout == null) {
      throw new TypeError(`setIconTheme: slot '${rawSlot}' must include source, textStyle, or layout`);
    }
  }
}

function isValidStreamHandle(handle: unknown): handle is StreamHandle {
  if (typeof handle === "bigint") {
    return handle >= 0n;
  }
  if (typeof handle === "number") {
    return Number.isFinite(handle) && handle >= 0;
  }
  return false;
}

function pbEncodeVarint(value: bigint): number[] {
  const out: number[] = [];
  let v = BigInt.asUintN(64, value);
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

function pbEncodeInt32(value: number): number[] {
  const i32 = BigInt.asIntN(32, BigInt(Math.trunc(value)));
  return pbEncodeVarint(BigInt.asUintN(64, i32));
}

function pbEncodeInt64(value: bigint): number[] {
  return pbEncodeVarint(BigInt.asUintN(64, value));
}

function pbEncodeBool(value: boolean): number[] {
  return pbEncodeVarint(value ? 1n : 0n);
}

function pbEncodeStringField(field: number, value: string): number[] {
  const data = PB_TEXT_ENCODER.encode(value);
  return [
    ...pbEncodeTag(field, 2),
    ...pbEncodeVarint(BigInt(data.length)),
    ...data,
  ];
}

function pbEncodeMessageField(field: number, payload: Uint8Array): number[] {
  return [
    ...pbEncodeTag(field, 2),
    ...pbEncodeVarint(BigInt(payload.length)),
    ...payload,
  ];
}

function pbEncodeInsertRowsRequest(
  gridId: number,
  index: number,
  count: number,
  text: string[],
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(Math.trunc(gridId))));
  out.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(index));
  out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(count));
  for (const rowText of text) {
    out.push(...pbEncodeStringField(4, rowText));
  }
  return new Uint8Array(out);
}

function pbEncodeCellRange(
  row1: number,
  col1: number,
  row2: number,
  col2: number,
): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt32(row1));
  out.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(col1));
  out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(row2));
  out.push(...pbEncodeTag(4, 0), ...pbEncodeInt32(col2));
  return new Uint8Array(out);
}

function pbEncodeSelectRequest(args: {
  gridId: number;
  row?: number;
  col?: number;
  rowEnd?: number;
  colEnd?: number;
  ranges?: ReadonlyArray<VolvoxGridCellRange>;
  show?: boolean;
}): Uint8Array {
  const out: number[] = [];
  const ranges = args.ranges && args.ranges.length > 0
    ? args.ranges
    : [{
      row1: args.row ?? 0,
      col1: args.col ?? 0,
      row2: args.rowEnd ?? args.row ?? 0,
      col2: args.colEnd ?? args.col ?? 0,
    }];
  const activeRow = args.row ?? ranges[0].row1;
  const activeCol = args.col ?? ranges[0].col1;
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(Math.trunc(args.gridId))));
  out.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(activeRow));
  out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(activeCol));
  for (const range of ranges) {
    out.push(...pbEncodeMessageField(4, pbEncodeCellRange(
      range.row1,
      range.col1,
      range.row2,
      range.col2,
    )));
  }
  if (args.show != null) {
    out.push(...pbEncodeTag(5, 0), ...pbEncodeBool(args.show));
  }
  return new Uint8Array(out);
}

function pbEncodeGetNodeRequest(gridId: number, row: number, relation?: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(Math.trunc(gridId))));
  out.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(row));
  if (relation != null) {
    out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(relation));
  }
  return new Uint8Array(out);
}

function pbEncodeGridHandleRequest(gridId: number): Uint8Array {
  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(Math.trunc(gridId))));
  return new Uint8Array(out);
}

function pbEncodeRenderPresentModeConfig(presentMode: number): Uint8Array {
  const renderConfig: number[] = [];
  // RenderConfig.present_mode = 6
  renderConfig.push(...pbEncodeTag(6, 0), ...pbEncodeInt32(Math.trunc(presentMode)));

  const gridConfig: number[] = [];
  // GridConfig.rendering = 9
  gridConfig.push(...pbEncodeMessageField(9, new Uint8Array(renderConfig)));
  return new Uint8Array(gridConfig);
}

function pbEncodeUint32Field(field: number, value: number): number[] {
  return [...pbEncodeTag(field, 0), ...pbEncodeVarint(BigInt(value >>> 0))];
}

function pbEncodeFloatField(field: number, value: number): number[] {
  const buf = new ArrayBuffer(4);
  new DataView(buf).setFloat32(0, value, true);
  return [...pbEncodeTag(field, 5), ...Array.from(new Uint8Array(buf))];
}

function pbEncodeFont(font: VolvoxGridFont): Uint8Array {
  const out: number[] = [];
  if (font.family != null) {
    out.push(...pbEncodeStringField(1, font.family));
  }
  for (const family of font.families ?? []) {
    out.push(...pbEncodeStringField(2, family));
  }
  if (font.size != null) {
    out.push(...pbEncodeFloatField(3, font.size));
  }
  if (font.bold != null) {
    out.push(...pbEncodeTag(4, 0), ...pbEncodeBool(font.bold));
  }
  if (font.italic != null) {
    out.push(...pbEncodeTag(5, 0), ...pbEncodeBool(font.italic));
  }
  if (font.underline != null) {
    out.push(...pbEncodeTag(6, 0), ...pbEncodeBool(font.underline));
  }
  if (font.strikethrough != null) {
    out.push(...pbEncodeTag(7, 0), ...pbEncodeBool(font.strikethrough));
  }
  if (font.width != null) {
    out.push(...pbEncodeFloatField(8, font.width));
  }
  return new Uint8Array(out);
}

function pbEncodePadding(padding: VolvoxGridPadding): Uint8Array {
  const out: number[] = [];
  if (padding.left != null) out.push(...pbEncodeTag(1, 0), ...pbEncodeInt32(padding.left));
  if (padding.top != null) out.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(padding.top));
  if (padding.right != null) out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(padding.right));
  if (padding.bottom != null) out.push(...pbEncodeTag(4, 0), ...pbEncodeInt32(padding.bottom));
  return new Uint8Array(out);
}

function pbEncodeBorder(border: VolvoxGridBorder): Uint8Array {
  const out: number[] = [];
  if (border.style != null) {
    out.push(...pbEncodeTag(1, 0), ...pbEncodeInt32(border.style));
  }
  if (border.colorArgb != null) {
    out.push(...pbEncodeUint32Field(2, border.colorArgb));
  }
  return new Uint8Array(out);
}

function pbEncodeBorders(borders: VolvoxGridBorders): Uint8Array {
  const out: number[] = [];
  const fields: Array<[number, VolvoxGridBorder | undefined]> = [
    [1, borders.all],
    [2, borders.top],
    [3, borders.right],
    [4, borders.bottom],
    [5, borders.left],
  ];
  for (const [field, border] of fields) {
    if (border == null) continue;
    const encoded = pbEncodeBorder(border);
    if (encoded.length > 0) {
      out.push(...pbEncodeMessageField(field, encoded));
    }
  }
  return new Uint8Array(out);
}

function pbEncodeCellStyle(style: VolvoxGridCellStyle): Uint8Array {
  const out: number[] = [];
  if (style.background != null) {
    out.push(...pbEncodeUint32Field(1, style.background));
  }
  if (style.foreground != null) {
    out.push(...pbEncodeUint32Field(2, style.foreground));
  }
  if (style.align != null) {
    out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(style.align));
  }
  if (style.font != null) {
    const font = pbEncodeFont(style.font);
    if (font.length > 0) {
      out.push(...pbEncodeMessageField(4, font));
    }
  }
  if (style.padding != null) {
    const padding = pbEncodePadding(style.padding);
    if (padding.length > 0) {
      out.push(...pbEncodeMessageField(5, padding));
    }
  }
  if (style.borders != null) {
    const borders = pbEncodeBorders(style.borders);
    if (borders.length > 0) {
      out.push(...pbEncodeMessageField(6, borders));
    }
  }
  if (style.textEffect != null) {
    out.push(...pbEncodeTag(7, 0), ...pbEncodeInt32(style.textEffect));
  }
  if (style.progress != null) {
    out.push(...pbEncodeFloatField(8, style.progress));
  }
  if (style.progressColor != null) {
    out.push(...pbEncodeUint32Field(9, style.progressColor));
  }
  if (style.shrinkToFit != null) {
    out.push(...pbEncodeTag(10, 0), ...pbEncodeBool(style.shrinkToFit));
  }
  return new Uint8Array(out);
}

function pbEncodeHeaderFeaturesConfig(features: VolvoxGridHeaderFeatures): Uint8Array {
  const header: number[] = [];
  if (features.sort != null) {
    header.push(...pbEncodeTag(1, 0), ...pbEncodeBool(features.sort));
  }
  if (features.reorder != null) {
    header.push(...pbEncodeTag(2, 0), ...pbEncodeBool(features.reorder));
  }
  if (features.chooser != null) {
    header.push(...pbEncodeTag(3, 0), ...pbEncodeBool(features.chooser));
  }
  const interaction: number[] = [];
  interaction.push(...pbEncodeMessageField(10, new Uint8Array(header)));
  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(8, new Uint8Array(interaction)));
  return new Uint8Array(gridConfig);
}

function pbEncodeResizePolicyConfig(policy: VolvoxGridResizePolicy): Uint8Array {
  const resize: number[] = [];
  if (policy.columns != null) {
    resize.push(...pbEncodeTag(1, 0), ...pbEncodeBool(policy.columns));
  }
  if (policy.rows != null) {
    resize.push(...pbEncodeTag(2, 0), ...pbEncodeBool(policy.rows));
  }
  if (policy.uniform != null) {
    resize.push(...pbEncodeTag(3, 0), ...pbEncodeBool(policy.uniform));
  }
  const interaction: number[] = [];
  interaction.push(...pbEncodeMessageField(1, new Uint8Array(resize)));
  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(8, new Uint8Array(interaction)));
  return new Uint8Array(gridConfig);
}

function pbEncodeFreezePolicyConfig(policy: VolvoxGridFreezePolicy): Uint8Array {
  const freeze: number[] = [];
  if (policy.columns != null) {
    freeze.push(...pbEncodeTag(1, 0), ...pbEncodeBool(policy.columns));
  }
  if (policy.rows != null) {
    freeze.push(...pbEncodeTag(2, 0), ...pbEncodeBool(policy.rows));
  }
  const interaction: number[] = [];
  interaction.push(...pbEncodeMessageField(2, new Uint8Array(freeze)));
  const gridConfig: number[] = [];
  gridConfig.push(...pbEncodeMessageField(8, new Uint8Array(interaction)));
  return new Uint8Array(gridConfig);
}

function pbEncodeRenderBufferInput(
  gridId: number,
  width: number,
  height: number,
): Uint8Array {
  const buffer: number[] = [];
  buffer.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(0n)); // handle (unused on wasm host)
  buffer.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(Math.trunc(width * 4))); // stride
  buffer.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(width));
  buffer.push(...pbEncodeTag(4, 0), ...pbEncodeInt32(height));

  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(Math.trunc(gridId))));
  out.push(...pbEncodeMessageField(5, new Uint8Array(buffer))); // RenderInput.buffer
  return new Uint8Array(out);
}

function pbEncodeFindTextRequest(
  gridId: number,
  col: number,
  startRow: number,
  text: string,
  caseSensitive: boolean,
  fullMatch: boolean,
): Uint8Array {
  const query: number[] = [];
  query.push(...pbEncodeStringField(1, text));
  query.push(...pbEncodeTag(2, 0), ...pbEncodeBool(caseSensitive));
  query.push(...pbEncodeTag(3, 0), ...pbEncodeBool(fullMatch));

  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(Math.trunc(gridId))));
  out.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(col));
  out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(startRow));
  out.push(...pbEncodeMessageField(4, new Uint8Array(query)));
  return new Uint8Array(out);
}

function pbEncodeFindRegexRequest(
  gridId: number,
  col: number,
  startRow: number,
  pattern: string,
): Uint8Array {
  const regex: number[] = [];
  regex.push(...pbEncodeStringField(1, pattern));

  const out: number[] = [];
  out.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(Math.trunc(gridId))));
  out.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(col));
  out.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(startRow));
  out.push(...pbEncodeMessageField(5, new Uint8Array(regex)));
  return new Uint8Array(out);
}

function pbVarintLenU32(value: number): number {
  const v = value >>> 0;
  if (v < 0x80) return 1;
  if (v < 0x4000) return 2;
  if (v < 0x200000) return 3;
  if (v < 0x10000000) return 4;
  return 5;
}

function pbVarintLenInt32(value: number): number {
  const i32 = Math.trunc(value);
  return i32 >= 0 ? pbVarintLenU32(i32) : 10;
}

class CellBackColorBatchEncoder {
  private buffer = new Uint8Array(0);

  private length = 0;

  private ensureCapacity(extra: number): void {
    const need = this.length + extra;
    if (need <= this.buffer.length) return;
    let nextCap = this.buffer.length > 0 ? this.buffer.length : 256;
    while (nextCap < need) {
      nextCap <<= 1;
    }
    const next = new Uint8Array(nextCap);
    if (this.length > 0) {
      next.set(this.buffer.subarray(0, this.length));
    }
    this.buffer = next;
  }

  private writeByte(value: number): void {
    this.ensureCapacity(1);
    this.buffer[this.length] = value & 0xff;
    this.length += 1;
  }

  private writeVarintU32(value: number): void {
    this.ensureCapacity(5);
    let v = value >>> 0;
    while (v >= 0x80) {
      this.buffer[this.length] = (v & 0x7f) | 0x80;
      this.length += 1;
      v >>>= 7;
    }
    this.buffer[this.length] = v;
    this.length += 1;
  }

  private writeVarintU64(value: bigint): void {
    this.ensureCapacity(10);
    let v = BigInt.asUintN(64, value);
    while (v >= 0x80n) {
      this.buffer[this.length] = Number((v & 0x7fn) | 0x80n);
      this.length += 1;
      v >>= 7n;
    }
    this.buffer[this.length] = Number(v);
    this.length += 1;
  }

  private writeVarintInt32(value: number): void {
    const i32 = Math.trunc(value);
    if (i32 >= 0) {
      this.writeVarintU32(i32);
      return;
    }
    this.writeVarintU64(BigInt.asUintN(64, BigInt(i32)));
  }

  encode(gridId: number, updates: ReadonlyArray<number>): Uint8Array {
    this.length = 0;

    // UpdateCellsRequest.grid_id (field 1, varint)
    this.writeByte(0x08);
    this.writeVarintU64(BigInt(Math.trunc(gridId)));

    for (let i = 0; i + 2 < updates.length; i += 3) {
      const row = Math.trunc(updates[i]);
      const col = Math.trunc(updates[i + 1]);
      const backColor = updates[i + 2] >>> 0;

      // CellStyle.background (field 1)
      const colorLen = pbVarintLenU32(backColor);
      const styleLen = 1 + colorLen; // tag(1) + color varint
      const styleLenLen = pbVarintLenU32(styleLen);
      const rowLen = pbVarintLenInt32(row);
      const colLen = pbVarintLenInt32(col);

      // CellUpdate payload bytes:
      // row(tag+varint) + col(tag+varint) + style(tag+len+payload)
      const cellLen = 1 + rowLen + 1 + colLen + 1 + styleLenLen + styleLen;

      // UpdateCellsRequest.cells (field 2, message)
      this.writeByte(0x12);
      this.writeVarintU32(cellLen);

      // CellUpdate.row (field 1)
      this.writeByte(0x08);
      this.writeVarintInt32(row);

      // CellUpdate.col (field 2)
      this.writeByte(0x10);
      this.writeVarintInt32(col);

      // CellUpdate.style (field 4, message)
      this.writeByte(0x22);
      this.writeVarintU32(styleLen);

      // CellStyle.background (field 1)
      this.writeByte(0x08);
      this.writeVarintU32(backColor);
    }

    return this.buffer.subarray(0, this.length);
  }
}

function pbReadVarint(data: Uint8Array, offset: number): { value: bigint; next: number } {
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

function pbSkipField(data: Uint8Array, offset: number, wireType: number): number {
  if (wireType === 0) {
    return pbReadVarint(data, offset).next;
  }
  if (wireType === 1) {
    return Math.min(data.length, offset + 8);
  }
  if (wireType === 2) {
    const len = pbReadVarint(data, offset);
    const n = Number(len.value);
    if (!Number.isFinite(n) || n < 0) return data.length;
    return Math.min(data.length, len.next + n);
  }
  if (wireType === 5) {
    return Math.min(data.length, offset + 4);
  }
  return data.length;
}

function pbAsInt32(value: bigint): number {
  return Number(BigInt.asIntN(32, value));
}

function pbDecodeFindRow(data: Uint8Array): number {
  let offset = 0;
  let row = -1;
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 0) {
      const v = pbReadVarint(data, offset);
      row = pbAsInt32(v.value);
      offset = v.next;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return row;
}

function pbDecodeAggregateValue(data: Uint8Array): number {
  let offset = 0;
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 1 && offset + 8 <= data.length) {
      const view = new DataView(data.buffer, data.byteOffset + offset, 8);
      return view.getFloat64(0, true);
    }
    offset = pbSkipField(data, offset, wire);
  }
  return Number.NaN;
}

function pbDecodeCellRange(data: Uint8Array): VolvoxGridCellRange | null {
  let offset = 0;
  const range: VolvoxGridCellRange = { row1: 0, col1: 0, row2: 0, col2: 0 };
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const v = pbReadVarint(data, offset);
      offset = v.next;
      const n = pbAsInt32(v.value);
      if (field === 1) range.row1 = n;
      if (field === 2) range.col1 = n;
      if (field === 3) range.row2 = n;
      if (field === 4) range.col2 = n;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  if (data.length === 0) return null;
  return range;
}

function pbDecodeSelectionState(data: Uint8Array): VolvoxGridSelection | null {
  let offset = 0;
  let row = -1;
  let col = -1;
  let topRow = 0;
  let leftCol = 0;
  let bottomRow = 0;
  let rightCol = 0;
  let mouseRow = 0;
  let mouseCol = 0;
  const ranges: VolvoxGridCellRange[] = [];

  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 3 && wire === 2) {
      const len = pbReadVarint(data, offset);
      const n = Number(len.value);
      if (Number.isFinite(n) && n >= 0) {
        const end = Math.min(data.length, len.next + n);
        const range = pbDecodeCellRange(data.slice(len.next, end));
        if (range != null) ranges.push(range);
      }
      offset = pbSkipField(data, offset, wire);
      continue;
    }
    if (wire === 0) {
      const value = pbReadVarint(data, offset);
      offset = value.next;
      const n = pbAsInt32(value.value);
      if (field === 1) row = n;
      if (field === 2) col = n;
      if (field === 4) topRow = n;
      if (field === 5) leftCol = n;
      if (field === 6) bottomRow = n;
      if (field === 7) rightCol = n;
      if (field === 8) mouseRow = n;
      if (field === 9) mouseCol = n;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }

  if (data.length === 0) return null;
  const activeRange = ranges.find((range) =>
    (range.row1 === row && range.col1 === col)
      || (range.row2 === row && range.col2 === col))
    ?? ranges[0];
  let rowEnd = row;
  let colEnd = col;
  if (activeRange != null) {
    if (activeRange.row1 === row && activeRange.col1 === col) {
      rowEnd = activeRange.row2;
      colEnd = activeRange.col2;
    } else if (activeRange.row2 === row && activeRange.col2 === col) {
      rowEnd = activeRange.row1;
      colEnd = activeRange.col1;
    } else {
      rowEnd = activeRange.row2;
      colEnd = activeRange.col2;
    }
  }
  return {
    row,
    col,
    rowEnd,
    colEnd,
    topRow,
    leftCol,
    bottomRow,
    rightCol,
    mouseRow,
    mouseCol,
    ranges,
  };
}

function pbDecodeNodeInfo(data: Uint8Array): VolvoxGridNodeInfo | null {
  let offset = 0;
  const node: VolvoxGridNodeInfo = {
    row: 0,
    level: 0,
    isExpanded: false,
    childCount: 0,
    parentRow: 0,
    firstChild: 0,
    lastChild: 0,
  };
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const v = pbReadVarint(data, offset);
      offset = v.next;
      const n = pbAsInt32(v.value);
      if (field === 1) node.row = n;
      if (field === 2) node.level = n;
      if (field === 3) node.isExpanded = n !== 0;
      if (field === 4) node.childCount = n;
      if (field === 5) node.parentRow = n;
      if (field === 6) node.firstChild = n;
      if (field === 7) node.lastChild = n;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  if (data.length === 0) return null;
  return node;
}

function pbDecodeGridEventEnvelope(
  data: Uint8Array,
): { eventId: bigint; eventField: number; payload: Uint8Array } | null {
  let offset = 0;
  let eventId = 0n;
  let eventField = 0;
  let payload = new Uint8Array(0);
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);

    if (field === 100 && wire === 0) {
      const value = pbReadVarint(data, offset);
      eventId = value.value;
      offset = value.next;
      continue;
    }

    if (wire === 2 && field >= 2 && field <= 60) {
      const len = pbReadVarint(data, offset);
      const n = Number(len.value);
      if (!Number.isFinite(n) || n < 0) {
        return null;
      }
      const start = len.next;
      const end = Math.min(data.length, start + n);
      eventField = field;
      payload = data.slice(start, end);
      offset = end;
      continue;
    }

    offset = pbSkipField(data, offset, wire);
  }
  if (eventField === 0) {
    return null;
  }
  return { eventId, eventField, payload };
}

function pbDecodeBeforeEditPayload(data: Uint8Array): { row: number; col: number } {
  let row = -1;
  let col = -1;
  let offset = 0;
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const value = pbReadVarint(data, offset);
      const n = pbAsInt32(value.value);
      offset = value.next;
      if (field === 1) row = n;
      if (field === 2) col = n;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return { row, col };
}

function pbDecodeCellEditValidatePayload(
  data: Uint8Array,
): { row: number; col: number; editText: string } {
  let row = -1;
  let col = -1;
  let editText = "";
  let offset = 0;
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const value = pbReadVarint(data, offset);
      const n = pbAsInt32(value.value);
      offset = value.next;
      if (field === 1) row = n;
      if (field === 2) col = n;
      continue;
    }
    if (field === 3 && wire === 2) {
      const len = pbReadVarint(data, offset);
      const n = Number(len.value);
      if (Number.isFinite(n) && n >= 0) {
        const end = Math.min(data.length, len.next + n);
        editText = PB_TEXT_DECODER.decode(data.slice(len.next, end));
      }
      offset = pbSkipField(data, offset, wire);
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return { row, col, editText };
}

function pbDecodeBeforeSortPayload(data: Uint8Array): { col: number } {
  let col = -1;
  let offset = 0;
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 0) {
      const value = pbReadVarint(data, offset);
      col = pbAsInt32(value.value);
      offset = value.next;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return { col };
}

function pbDecodeFrameDoneRect(
  data: Uint8Array,
): { x: number; y: number; w: number; h: number } | null {
  let offset = 0;
  const rect = { x: 0, y: 0, w: 0, h: 0 };
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (wire === 0) {
      const v = pbReadVarint(data, offset);
      offset = v.next;
      const n = pbAsInt32(v.value);
      if (field === 2) rect.x = n;
      if (field === 3) rect.y = n;
      if (field === 4) rect.w = n;
      if (field === 5) rect.h = n;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return rect.w > 0 && rect.h > 0 ? rect : null;
}

function pbDecodeRenderOutput(
  data: Uint8Array,
): { rendered: boolean; dirtyRect: { x: number; y: number; w: number; h: number } | null } {
  let offset = 0;
  let rendered = false;
  let dirtyRect: { x: number; y: number; w: number; h: number } | null = null;
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 0) {
      const v = pbReadVarint(data, offset);
      offset = v.next;
      rendered = v.value !== 0n;
      continue;
    }
    if (field === 2 && wire === 2) {
      const len = pbReadVarint(data, offset);
      const n = Number(len.value);
      if (Number.isFinite(n) && n > 0) {
        const end = Math.min(data.length, len.next + n);
        dirtyRect = pbDecodeFrameDoneRect(data.slice(len.next, end));
      }
      offset = pbSkipField(data, offset, wire);
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return { rendered, dirtyRect };
}

function pbDecodePrintPage(
  data: Uint8Array,
): { pageNumber: number; imageData: Uint8Array; width: number; height: number } | null {
  let offset = 0;
  let seenField = false;
  let pageNumber = 0;
  let imageData = new Uint8Array();
  let width = 0;
  let height = 0;

  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 0) {
      const v = pbReadVarint(data, offset);
      pageNumber = pbAsInt32(v.value);
      offset = v.next;
      seenField = true;
      continue;
    }
    if (field === 2 && wire === 2) {
      const len = pbReadVarint(data, offset);
      const n = Number(len.value);
      if (Number.isFinite(n) && n >= 0) {
        const end = Math.min(data.length, len.next + n);
        imageData = data.slice(len.next, end);
      }
      offset = pbSkipField(data, offset, wire);
      seenField = true;
      continue;
    }
    if (field === 3 && wire === 0) {
      const v = pbReadVarint(data, offset);
      width = pbAsInt32(v.value);
      offset = v.next;
      seenField = true;
      continue;
    }
    if (field === 4 && wire === 0) {
      const v = pbReadVarint(data, offset);
      height = pbAsInt32(v.value);
      offset = v.next;
      seenField = true;
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }

  if (!seenField) return null;
  return { pageNumber, imageData, width, height };
}

function pbDecodePrintResponse(
  data: Uint8Array,
): { pageNumber: number; imageData: Uint8Array; width: number; height: number }[] {
  let offset = 0;
  const pages: { pageNumber: number; imageData: Uint8Array; width: number; height: number }[] = [];
  while (offset < data.length) {
    const tag = pbReadVarint(data, offset);
    offset = tag.next;
    const field = Number(tag.value >> 3n);
    const wire = Number(tag.value & 0x7n);
    if (field === 1 && wire === 2) {
      const len = pbReadVarint(data, offset);
      const n = Number(len.value);
      if (Number.isFinite(n) && n >= 0) {
        const end = Math.min(data.length, len.next + n);
        const page = pbDecodePrintPage(data.slice(len.next, end));
        if (page) {
          pages.push(page);
        }
      }
      offset = pbSkipField(data, offset, wire);
      continue;
    }
    offset = pbSkipField(data, offset, wire);
  }
  return pages;
}

export class VolvoxGrid {
  private static readonly TOUCH_SCROLL_LINE_PX = 24;
  private static readonly TOUCH_PAN_START_PX = 2;
  private static readonly ZOOM_MIN_SCALE = 0.25;
  private static readonly ZOOM_MAX_SCALE = 4.0;
  private static readonly ZOOM_STEP_MIN_SCALE = 1 / 32;
  private static readonly ZOOM_STEP_MAX_SCALE = 32;
  private static readonly ZOOM_STEP_NOISE_EPSILON = 0.001;
  private wasm: any;
  private gridId: number;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D | null = null;
  private useGpu: boolean = false;
  private _presentMode: number = 0; // proto PresentMode (0=AUTO,1=FIFO,2=MAILBOX,3=IMMEDIATE)
  private animFrame: number = 0;
  private dirty: boolean = true;
  private destroyed: boolean = false;
  private resizeObserver: ResizeObserver | null = null;
  private lastFrameTs: number = 0;
  private renderMemoryBuffer: ArrayBufferLike | null = null;
  private renderPixelView: Uint8ClampedArray | null = null;
  private renderImageData: ImageData | null = null;
  private renderPtr: number = 0;
  private renderByteLength: number = 0;
  private renderWidth: number = 0;
  private renderHeight: number = 0;
  private gpuCanvas: HTMLCanvasElement | null = null;
  private cpuCanvas: HTMLCanvasElement | null = null;
  private canvasOpacityBeforeOverlay: string | null = null;
  private readonly touchPoints = new Map<number, { x: number; y: number }>();
  private touchMode: "none" | "pan" | "fast-scroll" | "pinch" = "none";
  private activeTouchPointerId: number | null = null;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private touchLastX: number = 0;
  private touchLastY: number = 0;
  private touchPanActive: boolean = false;
  private pinchLastDistance: number = 0;
  private pinchLastCenterX: number = 0;
  private pinchLastCenterY: number = 0;
  private readonly zoomScaleByGrid = new Map<number, number>();
  private readonly zoomBaseFontSizeByGrid = new Map<number, number>();
  private readonly zoomBaseRowHeightByGrid = new Map<number, number>();
  private readonly zoomBaseColWidthByGrid = new Map<number, number>();
  private readonly cellBackColorBatchEncoder = new CellBackColorBatchEncoder();
  onZoomChange: ((scale: number) => void) | null = null;
  private beforeEditListener: ((details: VolvoxGridBeforeEditDetails) => void) | null = null;
  private cellEditValidatingListener:
    ((details: VolvoxGridCellEditValidatingDetails) => void) | null = null;
  private beforeSortListener: ((details: VolvoxGridBeforeSortDetails) => void) | null = null;
  private manualEventDecisionEnabled: boolean = false;
  private dpr: number = 1;
  private dprX: number = 1;
  private dprY: number = 1;
  private pendingCanvasWidth: number = 0;
  private pendingCanvasHeight: number = 0;
  private pendingDpr: number = 0;
  private pendingDprX: number = 0;
  private pendingDprY: number = 0;
  private forcedRenderWidth: number = 0;
  private forcedRenderHeight: number = 0;
  private _maxDpr: number = 0;
  private presentCssWidth: number = 0;
  private presentCssHeight: number = 0;

  // Host-side editors for full caret/IME/text-selection UX.
  private editInput: HTMLInputElement;
  private editSelect: HTMLSelectElement;
  private editDataList: HTMLDataListElement;
  private editDataListId: string;
  private activeEditor: "none" | "text" | "combo-input" | "combo-select" = "none";
  private editorCellKey: string = "";
  private suppressEditorInput: boolean = false;
  /** When true, syncInputEditor skips select() so the host adapter controls caret/selection. */
  suppressEditorSelect: boolean = false;
  private suppressBlurCommit: boolean = false;
  private editComposing: boolean = false;

  private headerSeparatorStyle: ResolvedHeaderSeparatorStyle = {
    ...DEFAULT_HEADER_SEPARATOR_STYLE,
    height: { ...DEFAULT_HEADER_SEPARATOR_STYLE.height },
  };
  private headerResizeHandleStyle: ResolvedHeaderResizeHandleStyle = {
    ...DEFAULT_HEADER_RESIZE_HANDLE_STYLE,
    height: { ...DEFAULT_HEADER_RESIZE_HANDLE_STYLE.height },
  };
  private iconThemeStyleCache: {
    defaults?: VolvoxGridIconThemeDefaults;
    slots: Partial<Record<VolvoxGridIconSlotName, Pick<VolvoxGridIconSpec, "textStyle" | "layout">>>;
  } = { slots: {} };
  private selectionModeValue: number = 0;
  private selectionVisibilityValue: number = 1;
  private focusBorderValue: number = 0;
  private cellSpanModeValue: number = 0;
  private editTriggerValue: number = 2;
  private tabBehaviorValue: number = 1;
  private dropdownTriggerValue: number = 1;
  private dropdownSearchValue: boolean = true;
  private scrollBarsValue: number = 3;
  private animationEnabledValue: boolean = false;
  private animationDurationMsValue: number = 0;
  private textLayoutCacheCapValue: number = 0;

  /** Cancelable edit-start hook for the web canvas host. */
  get onBeforeEdit(): ((details: VolvoxGridBeforeEditDetails) => void) | null {
    return this.beforeEditListener;
  }

  set onBeforeEdit(listener: ((details: VolvoxGridBeforeEditDetails) => void) | null) {
    this.beforeEditListener = listener;
    this.syncCancelableEventDecisionSupport();
  }

  /** Cancelable edit-commit validation hook for the web canvas host. */
  get onCellEditValidating(): ((details: VolvoxGridCellEditValidatingDetails) => void) | null {
    return this.cellEditValidatingListener;
  }

  set onCellEditValidating(
    listener: ((details: VolvoxGridCellEditValidatingDetails) => void) | null,
  ) {
    this.cellEditValidatingListener = listener;
    this.syncCancelableEventDecisionSupport();
  }

  /** Cancelable header-sort hook for the web canvas host. */
  get onBeforeSort(): ((details: VolvoxGridBeforeSortDetails) => void) | null {
    return this.beforeSortListener;
  }

  set onBeforeSort(listener: ((details: VolvoxGridBeforeSortDetails) => void) | null) {
    this.beforeSortListener = listener;
    this.syncCancelableEventDecisionSupport();
  }

  /**
   * Create a VolvoxGrid instance.
   *
   * @param canvas  The canvas element to render into.
   * @param wasm    The initialised wasm-bindgen module (the default export
   *                from the wasm-pack generated JS glue).
   * @param rows    Initial row count for the grid body and any true fixed panes.
   * @param cols    Initial column count.
   */
  constructor(
    canvas: HTMLCanvasElement,
    wasm: any,
    rows: number = 10,
    cols: number = 5,
  ) {
    this.canvas = canvas;
    this.wasm = wasm;
    const rawDpr = window.devicePixelRatio || 1;
    this.dpr = Number.isFinite(rawDpr) && rawDpr > 0 ? rawDpr : 1;
    this.dprX = this.dpr;
    this.dprY = this.dpr;
    this.ensureCpuCanvasOverlay();

    // Context creation is deferred — tryInitGpu() may claim the canvas for
    // WebGPU. If GPU init fails (or is never attempted), ensureCtx() lazily
    // creates the 2D context on the first CPU render.

    // Create the engine-side grid
    if (typeof this.wasm.create_grid_scaled === "function") {
      this.gridId = Number(this.wasm.create_grid_scaled(rows, cols, this.dpr));
    } else {
      this.gridId = Number(wasm.create_grid(rows, cols));
    }

    // Web host defaults aligned with desktop-like behavior.
    if (typeof this.wasm.set_edit_trigger === "function") {
      this.wasm.set_edit_trigger(this.gridId, 2);
    } else {
      this.wasm.set_editable_mode(this.gridId, 2);
    }
    if (typeof this.wasm.set_dropdown_trigger === "function") {
      this.wasm.set_dropdown_trigger(this.gridId, 1);
    } else {
      this.wasm.set_show_combo_button(this.gridId, 1);
    }
    if (typeof this.wasm.set_dropdown_search === "function") {
      this.wasm.set_dropdown_search(this.gridId, 1);
    } else {
      this.wasm.set_combo_search(this.gridId, 1);
    }
    this.wasm.set_tab_behavior(this.gridId, 1); // Tab moves to next cell
    if (typeof this.wasm.set_host_dropdown_overlay === "function") {
      this.wasm.set_host_dropdown_overlay(this.gridId, 0);
    } else {
      this.wasm.set_host_combo_overlay(this.gridId, 0);
    } // engine renders the combo dropdown instead of a host overlay
    this.wasm.set_fling_enabled(this.gridId, 1); // inertial scroll
    if (typeof this.wasm.set_fast_scroll_enabled === "function") {
      this.wasm.set_fast_scroll_enabled(this.gridId, true);
    }
    if (typeof this.wasm.set_font_size === "function") {
      this.wasm.set_font_size(this.gridId, 11.0 * this.dpr);
    }
    if (typeof this.wasm.set_fling_impulse_gain === "function") {
      this.wasm.set_fling_impulse_gain(this.gridId, 220.0);
    }
    if (typeof this.wasm.set_fling_friction === "function") {
      this.wasm.set_fling_friction(this.gridId, 0.9);
    }

    this.ensureZoomBaseForGrid(this.gridId);

    this.editDataListId = `volvoxgrid-edit-list-${Math.random().toString(36).slice(2)}`;
    this.editInput = document.createElement("input");
    this.editSelect = document.createElement("select");
    this.editDataList = document.createElement("datalist");
    this.initHostEditors();

    // Sync canvas size
    this.syncSize(true);

    // Wire up DOM events
    this.setupEventListeners();

    // Watch for resize
    this.resizeObserver = new ResizeObserver(() => {
      this.syncSize();
      this.dirty = true;
    });
    this.resizeObserver.observe(this.canvas);

    // Kick off the render loop
    this.startRenderLoop();
  }

  // ── Properties ───────────────────────────────────────────────────────

  /** Engine-side grid ID for direct WASM calls. */
  get id(): number {
    return this.gridId;
  }

  get rowCount(): number {
    return this.wasm.get_rows(this.gridId);
  }
  set rowCount(n: number) {
    this.wasm.set_rows(this.gridId, n);
    this.dirty = true;
  }

  get colCount(): number {
    return this.wasm.get_cols(this.gridId);
  }
  set colCount(n: number) {
    this.wasm.set_cols(this.gridId, n);
    this.dirty = true;
  }

  get frozenRowCount(): number {
    return this.wasm.get_frozen_rows(this.gridId);
  }
  set frozenRowCount(n: number) {
    this.wasm.set_frozen_rows(this.gridId, n);
    this.dirty = true;
  }

  get frozenColCount(): number {
    return this.wasm.get_frozen_cols(this.gridId);
  }
  set frozenColCount(n: number) {
    this.wasm.set_frozen_cols(this.gridId, n);
    this.dirty = true;
  }

  get showColumnHeaders(): boolean {
    if (typeof this.wasm.get_show_column_headers === "function") {
      return Boolean(this.wasm.get_show_column_headers(this.gridId));
    }
    return false;
  }
  set showColumnHeaders(value: boolean) {
    if (typeof this.wasm.set_show_column_headers === "function") {
      this.wasm.set_show_column_headers(this.gridId, value);
      this.dirty = true;
    }
  }

  get columnIndicatorTopModeBits(): number {
    if (typeof this.wasm.get_col_indicator_top_mode_bits === "function") {
      return Number(this.wasm.get_col_indicator_top_mode_bits(this.gridId));
    }
    return 0;
  }
  set columnIndicatorTopModeBits(value: number) {
    if (typeof this.wasm.set_col_indicator_top_mode_bits === "function") {
      this.wasm.set_col_indicator_top_mode_bits(this.gridId, Math.max(0, Math.trunc(value)));
      this.dirty = true;
    }
  }

  get columnIndicatorTopRowCount(): number {
    if (typeof this.wasm.get_col_indicator_top_band_rows === "function") {
      return Number(this.wasm.get_col_indicator_top_band_rows(this.gridId));
    }
    return 0;
  }
  set columnIndicatorTopRowCount(value: number) {
    if (typeof this.wasm.set_col_indicator_top_band_rows === "function") {
      this.wasm.set_col_indicator_top_band_rows(this.gridId, Math.max(0, Math.trunc(value)));
      this.dirty = true;
    }
  }

  get showRowIndicator(): boolean {
    if (typeof this.wasm.get_show_row_indicator === "function") {
      return Boolean(this.wasm.get_show_row_indicator(this.gridId));
    }
    return false;
  }
  set showRowIndicator(value: boolean) {
    if (typeof this.wasm.set_show_row_indicator === "function") {
      this.wasm.set_show_row_indicator(this.gridId, value);
      this.dirty = true;
    }
  }

  get rowIndicatorStartModeBits(): number {
    if (typeof this.wasm.get_row_indicator_start_mode_bits === "function") {
      return Number(this.wasm.get_row_indicator_start_mode_bits(this.gridId));
    }
    return 0;
  }
  set rowIndicatorStartModeBits(value: number) {
    if (typeof this.wasm.set_row_indicator_start_mode_bits === "function") {
      this.wasm.set_row_indicator_start_mode_bits(this.gridId, Math.max(0, Math.trunc(value)));
      this.dirty = true;
    }
  }

  get rowIndicatorStartWidth(): number {
    if (typeof this.wasm.get_row_indicator_start_width === "function") {
      return Number(this.wasm.get_row_indicator_start_width(this.gridId));
    }
    return 35;
  }
  set rowIndicatorStartWidth(value: number) {
    if (typeof this.wasm.set_row_indicator_start_width === "function") {
      this.wasm.set_row_indicator_start_width(this.gridId, Math.max(1, Math.trunc(value)));
      this.dirty = true;
    }
  }

  get cursorRow(): number {
    return this.wasm.get_selection_row(this.gridId);
  }
  set cursorRow(row: number) {
    this.selectRange(row, this.cursorCol, row, this.cursorCol);
  }

  get cursorCol(): number {
    return this.wasm.get_selection_col(this.gridId);
  }
  set cursorCol(col: number) {
    this.selectRange(this.cursorRow, col, this.cursorRow, col);
  }

  private get selectionRowEndValue(): number {
    return this.wasm.get_selection_row_end(this.gridId);
  }

  private get selectionColEndValue(): number {
    return this.wasm.get_selection_col_end(this.gridId);
  }

  selectRange(
    row1: number,
    col1: number,
    row2: number = row1,
    col2: number = col1,
    show: boolean = false,
  ): void {
    this.selectRanges([{ row1, col1, row2, col2 }], row1, col1, show);
  }

  selectRanges(
    ranges: ReadonlyArray<VolvoxGridCellRange>,
    activeRow?: number,
    activeCol?: number,
    show: boolean = false,
  ): void {
    if (ranges.length === 0) return;
    if (typeof this.wasm.volvox_grid_select_pb === "function") {
      const request = pbEncodeSelectRequest({
        gridId: this.gridId,
        row: activeRow ?? ranges[0].row1,
        col: activeCol ?? ranges[0].col1,
        ranges,
        show,
      });
      this.wasm.volvox_grid_select_pb(request);
      this.dirty = true;
    }
  }

  getSelection(): VolvoxGridSelection {
    if (typeof this.wasm.volvox_grid_get_selection === "function") {
      const response = this.wasm.volvox_grid_get_selection(BigInt(this.gridId));
      const decoded = pbDecodeSelectionState(response);
      if (decoded != null) {
        return decoded;
      }
    }
    return {
      row: this.cursorRow,
      col: this.cursorCol,
      rowEnd: this.selectionRowEndValue,
      colEnd: this.selectionColEndValue,
      topRow: this.topRow,
      leftCol: this.leftCol,
      bottomRow: this.getBottomRow(),
      rightCol: this.getRightCol(),
      mouseRow: typeof this.wasm.get_mouse_row === "function"
        ? Number(this.wasm.get_mouse_row(this.gridId))
        : -1,
      mouseCol: typeof this.wasm.get_mouse_col === "function"
        ? Number(this.wasm.get_mouse_col(this.gridId))
        : -1,
      ranges: [{
        row1: Math.min(this.cursorRow, this.selectionRowEndValue),
        col1: Math.min(this.cursorCol, this.selectionColEndValue),
        row2: Math.max(this.cursorRow, this.selectionRowEndValue),
        col2: Math.max(this.cursorCol, this.selectionColEndValue),
      }],
    };
  }

  showCell(row: number, col: number): void {
    if (typeof this.wasm.volvox_grid_show_cell === "function") {
      this.wasm.volvox_grid_show_cell(BigInt(this.gridId), row, col);
      this.dirty = true;
      return;
    }
    this.selectRange(row, col, row, col, true);
  }

  clearSelection(): void {
    this.selectRange(this.cursorRow, this.cursorCol, this.cursorRow, this.cursorCol, false);
  }

  get zoomScale(): number {
    return this.zoomScaleByGrid.get(this.gridId) ?? 1.0;
  }

  set zoomScale(scale: number) {
    const prev = this.zoomScaleByGrid.get(this.gridId) ?? 1.0;
    this.applyZoomScaleToCurrentGrid(scale, prev);
    this.zoomScaleByGrid.set(this.gridId, Math.max(
      VolvoxGrid.ZOOM_MIN_SCALE,
      Math.min(VolvoxGrid.ZOOM_MAX_SCALE, scale),
    ));
  }

  // ── Cell data ────────────────────────────────────────────────────────

  setCellText(row: number, col: number, text: string): void {
    this.wasm.set_text_matrix(this.gridId, row, col, text);
    this.dirty = true;
  }

  getCellText(row: number, col: number): string {
    return this.wasm.get_text_matrix(this.gridId, row, col);
  }

  private setTextArray(index: number, text: string): void {
    if (typeof this.wasm.set_text_array === "function") {
      this.wasm.set_text_array(this.gridId, index, text);
      this.dirty = true;
    }
  }

  private getTextArray(index: number): string {
    if (typeof this.wasm.get_text_array === "function") {
      return this.wasm.get_text_array(this.gridId, index);
    }
    const cols = Math.max(1, this.colCount);
    const row = Math.floor(index / cols);
    const col = index % cols;
    return this.getCellText(row, col);
  }

  setCells(cells: ReadonlyArray<VolvoxGridCellTextEntry>): void {
    if (cells.length === 0) {
      return;
    }
    if (typeof this.wasm.volvox_grid_update_cells_pb === "function") {
      const request: number[] = [];
      request.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(this.gridId)));
      for (const cell of cells) {
        const value: number[] = [];
        value.push(...pbEncodeStringField(1, cell.text));

        const update: number[] = [];
        update.push(...pbEncodeTag(1, 0), ...pbEncodeInt32(cell.row));
        update.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(cell.col));
        update.push(...pbEncodeMessageField(3, new Uint8Array(value)));
        request.push(...pbEncodeMessageField(2, new Uint8Array(update)));
      }
      this.wasm.volvox_grid_update_cells_pb(new Uint8Array(request));
      this.dirty = true;
      return;
    }
    for (const cell of cells) {
      this.setCellText(cell.row, cell.col, cell.text);
    }
  }

  loadTable(rows: number, cols: number, values: unknown[]): void {
    if (typeof this.wasm.load_array === "function") {
      this.wasm.load_array(this.gridId, rows, cols, values);
    } else {
      this.rowCount = rows;
      this.colCount = cols;
      const max = Math.max(1, rows) * Math.max(1, cols);
      for (let i = 0; i < values.length && i < max; i += 1) {
        this.setTextArray(i, values[i] == null ? "" : String(values[i]));
      }
    }
    this.dirty = true;
  }

  /** Insert rows before [index] (`-1` appends), optional tab-text per row. */
  insertRows(index: number, count: number = 1, text: string[] = []): void {
    const safeCount = Math.max(0, Math.trunc(count));
    if (safeCount <= 0) return;

    if (typeof this.wasm.volvox_grid_insert_rows_pb === "function") {
      const req = pbEncodeInsertRowsRequest(this.gridId, index, safeCount, text);
      this.wasm.volvox_grid_insert_rows_pb(req);
      this.dirty = true;
      return;
    }

    const base = Math.trunc(index);
    for (let i = 0; i < safeCount; i += 1) {
      const rowText = i < text.length ? text[i] : "";
      const atRow = base < 0 ? -1 : base + i;
      this.addItem(rowText, atRow);
    }
  }

  /** Remove [count] rows starting at [index]. */
  removeRows(index: number, count: number = 1): void {
    const safeCount = Math.max(0, Math.trunc(count));
    if (safeCount <= 0) return;

    if (typeof this.wasm.volvox_grid_remove_rows === "function") {
      this.wasm.volvox_grid_remove_rows(BigInt(this.gridId), index, safeCount);
      this.dirty = true;
      return;
    }

    for (let i = 0; i < safeCount; i += 1) {
      this.removeItem(index);
    }
  }

  /** Move a column to [position]. */
  moveColumn(col: number, position: number): void {
    if (typeof this.wasm.volvox_grid_move_column === "function") {
      this.wasm.volvox_grid_move_column(BigInt(this.gridId), col, position);
      this.dirty = true;
    }
  }

  /** Move a row to [position]. */
  moveRow(row: number, position: number): void {
    if (typeof this.wasm.volvox_grid_move_row === "function") {
      this.wasm.volvox_grid_move_row(BigInt(this.gridId), row, position);
      this.dirty = true;
    }
  }

  setCellFlood(row: number, col: number, percent: number, color: number): void {
    if (typeof this.wasm.set_cell_progress === "function") {
      this.wasm.set_cell_progress(this.gridId, row, col, percent, color);
    } else {
      this.wasm.set_cell_flood(this.gridId, row, col, percent, color);
    }
    this.dirty = true;
  }

  /** Batch per-cell background colors via UpdateCells protobuf.
   *  `updates` is a flat triplet array: [row0, col0, argb0, row1, col1, argb1, ...]. */
  setCellBackColors(updates: ReadonlyArray<number>): void {
    if (updates.length < 3) return;
    if (typeof this.wasm.volvox_grid_update_cells_pb === "function") {
      // Benchmark hack: aggressively reuse protobuf encoder buffers so JS-side
      // marshalling overhead is minimized and DOOM numbers better reflect
      // engine-side update/render cost.
      const req = this.cellBackColorBatchEncoder.encode(this.gridId, updates);
      this.wasm.volvox_grid_update_cells_pb(req);
      this.dirty = true;
    }
  }

  // ── Sizing ───────────────────────────────────────────────────────────

  setColWidth(col: number, w: number): void {
    this.wasm.set_col_width(this.gridId, col, w);
    this.dirty = true;
  }

  setColumnCaption(col: number, caption: string): void {
    if (typeof this.wasm.set_col_caption === "function") {
      this.wasm.set_col_caption(this.gridId, col, caption);
      this.dirty = true;
    }
  }

  getColWidth(col: number): number {
    return this.wasm.get_col_width(this.gridId, col);
  }

  get defaultColWidth(): number {
    if (typeof this.wasm.get_default_col_width === "function") {
      return Number(this.wasm.get_default_col_width(this.gridId));
    }
    const fixedCols = Number(this.wasm.get_fixed_cols?.(this.gridId) ?? 0);
    return this.getColWidth(Math.max(0, fixedCols));
  }

  set defaultColWidth(w: number) {
    if (typeof this.wasm.set_default_col_width === "function") {
      this.wasm.set_default_col_width(this.gridId, w);
    } else {
      this.wasm.set_col_width(this.gridId, -1, w);
    }
    this.dirty = true;
  }

  setRowHeight(row: number, h: number): void {
    this.wasm.set_row_height(this.gridId, row, h);
    this.dirty = true;
  }

  getRowHeight(row: number): number {
    return this.wasm.get_row_height(this.gridId, row);
  }

  get defaultRowHeight(): number {
    if (typeof this.wasm.get_default_row_height === "function") {
      return Number(this.wasm.get_default_row_height(this.gridId));
    }
    const fixedRows = Number(this.wasm.get_fixed_rows?.(this.gridId) ?? 0);
    const probeRow = Math.min(
      Math.max(0, fixedRows),
      Math.max(0, this.rowCount - 1),
    );
    return this.getRowHeight(probeRow);
  }

  set defaultRowHeight(h: number) {
    if (typeof this.wasm.set_default_row_height === "function") {
      this.wasm.set_default_row_height(this.gridId, h);
    } else {
      this.wasm.set_row_height(this.gridId, -1, h);
    }
    this.dirty = true;
  }

  /**
   * Override the internal render buffer resolution while keeping the canvas'
   * CSS layout size unchanged. Pass null/null to restore automatic sizing.
   */
  setRenderResolution(width: number | null, height: number | null = null): void {
    let nextW = 0;
    let nextH = 0;
    if (width != null && height != null) {
      const w = Math.round(Number(width));
      const h = Math.round(Number(height));
      if (Number.isFinite(w) && Number.isFinite(h) && w > 0 && h > 0) {
        nextW = w;
        nextH = h;
      }
    }

    if (nextW === this.forcedRenderWidth && nextH === this.forcedRenderHeight) {
      return;
    }

    this.forcedRenderWidth = nextW;
    this.forcedRenderHeight = nextH;
    this.syncSize();
    this.dirty = true;
  }

  /**
   * Cap the device-pixel-ratio used for rendering.
   *
   * On high-DPR displays (e.g. 2.0) this can dramatically reduce
   * the pixel count and improve FPS.  Set to 0 (default) for no cap.
   * A value of 1.0 renders at CSS resolution; 1.5 is a good quality/perf
   * balance on 2x displays.
   */
  get maxDpr(): number {
    return this._maxDpr;
  }

  set maxDpr(value: number) {
    const v = Number(value);
    const next = Number.isFinite(v) && v > 0 ? v : 0;
    if (next === this._maxDpr) return;
    this._maxDpr = next;
    this.syncSize();
    this.dirty = true;
  }

  // ── Appearance ───────────────────────────────────────────────────────

  get selectionMode(): number {
    if (typeof this.wasm.get_selection_mode === "function") {
      this.selectionModeValue = Number(this.wasm.get_selection_mode(this.gridId));
    }
    return this.selectionModeValue;
  }

  set selectionMode(mode: number) {
    this.selectionModeValue = Math.trunc(mode);
    this.wasm.set_selection_mode(this.gridId, this.selectionModeValue);
    this.dirty = true;
  }

  get selectionVisibility(): number {
    if (typeof this.wasm.get_selection_visibility === "function") {
      this.selectionVisibilityValue = Number(this.wasm.get_selection_visibility(this.gridId));
    } else if (typeof this.wasm.get_highlight === "function") {
      this.selectionVisibilityValue = Number(this.wasm.get_highlight(this.gridId));
    }
    return this.selectionVisibilityValue;
  }

  set selectionVisibility(mode: number) {
    this.selectionVisibilityValue = Math.trunc(mode);
    if (typeof this.wasm.set_selection_visibility === "function") {
      this.wasm.set_selection_visibility(this.gridId, this.selectionVisibilityValue);
    } else {
      this.wasm.set_highlight(this.gridId, this.selectionVisibilityValue);
    }
    this.dirty = true;
  }

  get focusBorder(): number {
    if (typeof this.wasm.get_focus_border === "function") {
      this.focusBorderValue = Number(this.wasm.get_focus_border(this.gridId));
    } else if (typeof this.wasm.get_focus_rect === "function") {
      this.focusBorderValue = Number(this.wasm.get_focus_rect(this.gridId));
    }
    return this.focusBorderValue;
  }

  set focusBorder(style: number) {
    this.focusBorderValue = Math.trunc(style);
    if (typeof this.wasm.set_focus_border === "function") {
      this.wasm.set_focus_border(this.gridId, this.focusBorderValue);
    } else {
      this.wasm.set_focus_rect(this.gridId, this.focusBorderValue);
    }
    this.dirty = true;
  }

  setFontName(name: string): void {
    if (typeof this.wasm.set_font_name === "function") {
      this.wasm.set_font_name(this.gridId, name);
      this.dirty = true;
    }
  }

  setFontSize(size: number): void {
    if (typeof this.wasm.set_font_size === "function") {
      this.wasm.set_font_size(this.gridId, size);
      this.dirty = true;
    }
  }

  get cellSpanMode(): number {
    if (typeof this.wasm.get_span_mode === "function") {
      this.cellSpanModeValue = Number(this.wasm.get_span_mode(this.gridId));
    }
    return this.cellSpanModeValue;
  }

  set cellSpanMode(mode: number) {
    this.cellSpanModeValue = Math.trunc(mode);
    this.wasm.set_span_mode(this.gridId, this.cellSpanModeValue);
    this.dirty = true;
  }

  mergeCells(r1: number, c1: number, r2: number, c2: number): void {
    this.wasm.merge_cells(this.gridId, r1, c1, r2, c2);
    this.dirty = true;
  }

  unmergeCells(r1: number, c1: number, r2: number, c2: number): void {
    this.wasm.unmerge_cells(this.gridId, r1, c1, r2, c2);
    this.dirty = true;
  }

  getMergedRegions(): { row1: number; col1: number; row2: number; col2: number }[] {
    const flat: Int32Array = this.wasm.get_merged_regions(this.gridId);
    const result: { row1: number; col1: number; row2: number; col2: number }[] = [];
    for (let i = 0; i < flat.length; i += 4) {
      result.push({ row1: flat[i], col1: flat[i + 1], row2: flat[i + 2], col2: flat[i + 3] });
    }
    return result;
  }

  /** Set legacy grid line mode: 0=none, 1=solid both, 2=inset both, 3=raised both, 4=solid horizontal, 5=solid vertical, 6=inset horizontal, 7=inset vertical, 8=raised horizontal, 9=raised vertical */
  setGridLines(mode: number): void {
    this.wasm.set_grid_lines(this.gridId, mode);
    this.dirty = true;
  }

  private applyProtoConfig(config: Uint8Array, context: string): void {
    if (typeof this.wasm.volvox_grid_configure !== "function") {
      return;
    }
    try {
      this.wasm.volvox_grid_configure(BigInt(this.gridId), config);
    } catch (e) {
      console.warn(`VolvoxGrid: failed to apply ${context} via proto config`, e);
    }
  }

  setHeaderFeatures(features: VolvoxGridHeaderFeatures): void {
    this.applyProtoConfig(pbEncodeHeaderFeaturesConfig(features), "HeaderFeatures");
    this.dirty = true;
  }

  setResizePolicy(policy: VolvoxGridResizePolicy): void {
    this.applyProtoConfig(pbEncodeResizePolicyConfig(policy), "ResizePolicy");
    this.dirty = true;
  }

  setFreezePolicy(policy: VolvoxGridFreezePolicy): void {
    this.applyProtoConfig(pbEncodeFreezePolicyConfig(policy), "FreezePolicy");
    this.dirty = true;
  }

  private normalizeHeaderMarkHeight(
    input: VolvoxGridHeaderMarkHeight | undefined,
    fallback: VolvoxGridHeaderMarkHeight,
  ): VolvoxGridHeaderMarkHeight {
    if (input == null) {
      return { ...fallback };
    }
    if (input.mode === "px") {
      const raw = Number(input.value);
      if (!Number.isFinite(raw)) {
        return { ...fallback };
      }
      return { mode: "px", value: Math.max(1, Math.round(raw)) };
    }
    if (input.mode === "ratio") {
      const raw = Number(input.value);
      if (!Number.isFinite(raw)) {
        return { ...fallback };
      }
      return { mode: "ratio", value: Math.max(0, Math.min(1, raw)) };
    }
    return { ...fallback };
  }

  private normalizeArgbColor(value: number | undefined, fallback: number): number {
    if (typeof value !== "number" || !Number.isFinite(value)) {
      return fallback >>> 0;
    }
    return (Math.trunc(value) >>> 0);
  }

  private applyHeaderSeparatorStyleToEngine(style: ResolvedHeaderSeparatorStyle): void {
    if (typeof this.wasm.set_header_separator_style !== "function") {
      return;
    }
    const heightMode = style.height.mode === "px" ? 1 : 0;
    this.wasm.set_header_separator_style(
      this.gridId,
      style.enabled ? 1 : 0,
      style.colorArgb >>> 0,
      Math.max(1, Math.round(style.widthPx)),
      heightMode,
      Number(style.height.value),
      style.skipMerged ? 1 : 0,
    );
    this.dirty = true;
  }

  private applyHeaderResizeHandleStyleToEngine(style: ResolvedHeaderResizeHandleStyle): void {
    if (typeof this.wasm.set_header_resize_handle_style !== "function") {
      return;
    }
    const heightMode = style.height.mode === "px" ? 1 : 0;
    this.wasm.set_header_resize_handle_style(
      this.gridId,
      style.enabled ? 1 : 0,
      style.colorArgb >>> 0,
      Math.max(1, Math.round(style.widthPx)),
      heightMode,
      Number(style.height.value),
      Math.max(1, Math.round(style.hitWidthPx)),
      style.showOnlyWhenResizable ? 1 : 0,
    );
    this.dirty = true;
  }

  setHeaderSeparator(style: VolvoxGridHeaderSeparator): void {
    const next: ResolvedHeaderSeparatorStyle = {
      enabled: style.enabled ?? this.headerSeparatorStyle.enabled,
      colorArgb: this.normalizeArgbColor(style.colorArgb, this.headerSeparatorStyle.colorArgb),
      widthPx: Math.max(
        1,
        Math.round(style.widthPx ?? this.headerSeparatorStyle.widthPx),
      ),
      height: this.normalizeHeaderMarkHeight(style.height, this.headerSeparatorStyle.height),
      skipMerged: style.skipMerged ?? this.headerSeparatorStyle.skipMerged,
    };
    this.headerSeparatorStyle = {
      ...next,
      height: { ...next.height },
    };
    this.applyHeaderSeparatorStyleToEngine(this.headerSeparatorStyle);
  }

  setHeaderSeparatorStyle(style: VolvoxGridHeaderSeparatorStyle): void {
    this.setHeaderSeparator(style);
  }

  getHeaderSeparator(): VolvoxGridHeaderSeparator {
    return {
      ...this.headerSeparatorStyle,
      height: { ...this.headerSeparatorStyle.height },
    };
  }

  getHeaderSeparatorStyle(): VolvoxGridHeaderSeparatorStyle {
    return this.getHeaderSeparator();
  }

  setHeaderResizeHandle(style: VolvoxGridHeaderResizeHandle): void {
    const next: ResolvedHeaderResizeHandleStyle = {
      enabled: style.enabled ?? this.headerResizeHandleStyle.enabled,
      colorArgb: this.normalizeArgbColor(style.colorArgb, this.headerResizeHandleStyle.colorArgb),
      widthPx: Math.max(
        1,
        Math.round(style.widthPx ?? this.headerResizeHandleStyle.widthPx),
      ),
      height: this.normalizeHeaderMarkHeight(style.height, this.headerResizeHandleStyle.height),
      hitWidthPx: Math.max(
        1,
        Math.round(style.hitWidthPx ?? this.headerResizeHandleStyle.hitWidthPx),
      ),
      showOnlyWhenResizable:
        style.showOnlyWhenResizable ?? this.headerResizeHandleStyle.showOnlyWhenResizable,
    };
    this.headerResizeHandleStyle = {
      ...next,
      height: { ...next.height },
    };
    this.applyHeaderResizeHandleStyleToEngine(this.headerResizeHandleStyle);
  }

  setHeaderResizeHandleStyle(style: VolvoxGridHeaderResizeHandleStyle): void {
    this.setHeaderResizeHandle(style);
  }

  getHeaderResizeHandle(): VolvoxGridHeaderResizeHandle {
    return {
      ...this.headerResizeHandleStyle,
      height: { ...this.headerResizeHandleStyle.height },
    };
  }

  getHeaderResizeHandleStyle(): VolvoxGridHeaderResizeHandleStyle {
    return this.getHeaderResizeHandle();
  }

  setGroupCompare(compare: number): void {
    if (typeof this.wasm.set_group_compare === "function") {
      this.wasm.set_group_compare(this.gridId, compare);
      this.dirty = true;
    }
  }

  getGroupCompare(): number {
    if (typeof this.wasm.get_group_compare === "function") {
      return Number(this.wasm.get_group_compare(this.gridId));
    }
    return 0;
  }

  get editTrigger(): number {
    if (typeof this.wasm.get_edit_trigger === "function") {
      this.editTriggerValue = Number(this.wasm.get_edit_trigger(this.gridId));
    } else if (typeof this.wasm.get_editable_mode === "function") {
      this.editTriggerValue = Number(this.wasm.get_editable_mode(this.gridId));
    }
    return this.editTriggerValue;
  }

  set editTrigger(mode: number) {
    this.editTriggerValue = Math.trunc(mode);
    if (typeof this.wasm.set_edit_trigger === "function") {
      this.wasm.set_edit_trigger(this.gridId, this.editTriggerValue);
    } else {
      this.wasm.set_editable_mode(this.gridId, this.editTriggerValue);
    }
    this.dirty = true;
  }

  get editable(): boolean {
    return this.editTrigger !== 0;
  }

  set editable(enabled: boolean) {
    const current = this.editTrigger;
    const next = enabled
      ? (current === 0 ? 2 : current)
      : 0;
    this.editTrigger = next;
  }

  get tabBehavior(): number {
    if (typeof this.wasm.get_tab_behavior === "function") {
      this.tabBehaviorValue = Number(this.wasm.get_tab_behavior(this.gridId));
    }
    return this.tabBehaviorValue;
  }

  set tabBehavior(mode: number) {
    this.tabBehaviorValue = Math.trunc(mode);
    this.wasm.set_tab_behavior(this.gridId, this.tabBehaviorValue);
    this.dirty = true;
  }

  get dropdownTrigger(): number {
    if (typeof this.wasm.get_dropdown_trigger === "function") {
      this.dropdownTriggerValue = Number(this.wasm.get_dropdown_trigger(this.gridId));
    } else if (typeof this.wasm.get_show_combo_button === "function") {
      this.dropdownTriggerValue = Number(this.wasm.get_show_combo_button(this.gridId));
    }
    return this.dropdownTriggerValue;
  }

  set dropdownTrigger(mode: number) {
    this.dropdownTriggerValue = Math.trunc(mode);
    if (typeof this.wasm.set_dropdown_trigger === "function") {
      this.wasm.set_dropdown_trigger(this.gridId, this.dropdownTriggerValue);
    } else {
      this.wasm.set_show_combo_button(this.gridId, this.dropdownTriggerValue);
    }
    this.dirty = true;
  }

  get dropdownSearch(): boolean {
    if (typeof this.wasm.get_dropdown_search === "function") {
      this.dropdownSearchValue = Boolean(this.wasm.get_dropdown_search(this.gridId));
    } else if (typeof this.wasm.get_combo_search === "function") {
      this.dropdownSearchValue = Boolean(this.wasm.get_combo_search(this.gridId));
    }
    return this.dropdownSearchValue;
  }

  set dropdownSearch(enabled: boolean) {
    this.dropdownSearchValue = Boolean(enabled);
    if (typeof this.wasm.set_dropdown_search === "function") {
      this.wasm.set_dropdown_search(this.gridId, this.dropdownSearchValue ? 1 : 0);
    } else {
      this.wasm.set_combo_search(this.gridId, this.dropdownSearchValue ? 1 : 0);
    }
    this.dirty = true;
  }

  get editMaxLength(): number {
    if (typeof this.wasm.get_edit_max_length === "function") {
      return Number(this.wasm.get_edit_max_length(this.gridId));
    }
    return 0;
  }

  set editMaxLength(maxChars: number) {
    this.wasm.set_edit_max_length(this.gridId, Math.trunc(maxChars));
    this.dirty = true;
  }

  get editText(): string {
    if (typeof this.wasm.get_edit_text === "function") {
      return String(this.wasm.get_edit_text(this.gridId) ?? "");
    }
    return "";
  }

  set editText(text: string) {
    if (typeof this.wasm.set_edit_text === "function") {
      this.wasm.set_edit_text(this.gridId, text);
      this.dirty = true;
    }
  }

  set topRow(row: number) {
    if (typeof this.wasm.set_top_row === "function") {
      this.wasm.set_top_row(this.gridId, row);
      this.dirty = true;
    }
  }

  get topRow(): number {
    if (typeof this.wasm.get_top_row === "function") {
      return Number(this.wasm.get_top_row(this.gridId));
    }
    return this.getVisibleRowRange().first;
  }

  set leftCol(col: number) {
    if (typeof this.wasm.set_left_col === "function") {
      this.wasm.set_left_col(this.gridId, col);
      this.dirty = true;
    }
  }

  get leftCol(): number {
    if (typeof this.wasm.get_left_col === "function") {
      return Number(this.wasm.get_left_col(this.gridId));
    }
    return 0;
  }

  getBottomRow(): number {
    if (typeof this.wasm.get_bottom_row === "function") {
      return Number(this.wasm.get_bottom_row(this.gridId));
    }
    return this.getVisibleRowRange().last;
  }

  getRightCol(): number {
    if (typeof this.wasm.get_right_col === "function") {
      return Number(this.wasm.get_right_col(this.gridId));
    }
    return -1;
  }

  getRowPos(row: number): number {
    if (typeof this.wasm.get_row_pos === "function") {
      return Number(this.wasm.get_row_pos(this.gridId, row));
    }
    return 0;
  }

  getColPos(col: number): number {
    if (typeof this.wasm.get_col_pos === "function") {
      return Number(this.wasm.get_col_pos(this.gridId, col));
    }
    return 0;
  }

  setRowData(row: number, data: Uint8Array): void {
    if (typeof this.wasm.set_row_data === "function") {
      this.wasm.set_row_data(this.gridId, row, data);
    }
  }

  getRowData(row: number): Uint8Array {
    if (typeof this.wasm.get_row_data === "function") {
      return this.wasm.get_row_data(this.gridId, row) as Uint8Array;
    }
    return new Uint8Array();
  }

  setRowStatus(row: number, status: number): void {
    if (typeof this.wasm.set_row_status === "function") {
      this.wasm.set_row_status(this.gridId, row, status);
    }
  }

  getRowStatus(row: number): number {
    if (typeof this.wasm.get_row_status === "function") {
      return Number(this.wasm.get_row_status(this.gridId, row));
    }
    return 0;
  }

  setCellStyle(row: number, col: number, style: VolvoxGridCellStyle): void {
    if (typeof this.wasm.volvox_grid_update_cells_pb === "function") {
      const stylePayload = pbEncodeCellStyle(style);
      if (stylePayload.length === 0) {
        return;
      }

      const cellUpdate: number[] = [];
      cellUpdate.push(...pbEncodeTag(1, 0), ...pbEncodeInt32(row));
      cellUpdate.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(col));
      cellUpdate.push(...pbEncodeMessageField(4, stylePayload));

      const request: number[] = [];
      request.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(this.gridId)));
      request.push(...pbEncodeMessageField(2, new Uint8Array(cellUpdate)));

      this.wasm.volvox_grid_update_cells_pb(new Uint8Array(request));
      this.dirty = true;
    }
  }

  // ── Pin & Sticky ─────────────────────────────────────────────────────

  /** Pin position constants. */
  static readonly PIN_NONE = 0;
  static readonly PIN_TOP = 1;
  static readonly PIN_BOTTOM = 2;
  static readonly PIN_COL_NONE = 0;
  static readonly PIN_COL_LEFT = 1;
  static readonly PIN_COL_RIGHT = 2;

  /** Sticky edge constants. */
  static readonly STICKY_NONE = 0;
  static readonly STICKY_TOP = 1;
  static readonly STICKY_BOTTOM = 2;
  static readonly STICKY_LEFT = 3;
  static readonly STICKY_RIGHT = 4;
  static readonly STICKY_BOTH = 5;

  /** Archive action constants. */
  static readonly ARCHIVE_SAVE = 0;
  static readonly ARCHIVE_LOAD = 1;
  static readonly ARCHIVE_DELETE = 2;
  static readonly ARCHIVE_LIST = 3;

  /** Pin a row to the top or bottom section, or unpin it (0=none, 1=top, 2=bottom). */
  pinRow(row: number, pin: number): void {
    this.wasm.pin_row(this.gridId, row, pin);
    this.dirty = true;
  }

  /** Check whether a row is pinned. Returns 0=none, 1=top, 2=bottom. */
  isRowPinned(row: number): number {
    return Number(this.wasm.is_row_pinned(this.gridId, row));
  }

  /** Pin a column to the left or right section, or unpin it (0=none, 1=left, 2=right). */
  pinCol(col: number, pin: number): void {
    if (typeof this.wasm.pin_col === "function") {
      this.wasm.pin_col(this.gridId, col, pin);
      this.dirty = true;
    }
  }

  /** Check whether a column is pinned. Returns 0=none, 1=left, 2=right. */
  isColPinned(col: number): number {
    if (typeof this.wasm.is_col_pinned === "function") {
      return Number(this.wasm.is_col_pinned(this.gridId, col));
    }
    return 0;
  }

  /** Set the sticky edge for a row (0=none, 1=TOP, 2=BOTTOM, 5=BOTH). */
  setRowSticky(row: number, edge: number): void {
    this.wasm.set_row_sticky(this.gridId, row, edge);
    this.dirty = true;
  }

  /** Set the sticky edge for a column (0=none, 3=LEFT, 4=RIGHT, 5=BOTH). */
  setColSticky(col: number, edge: number): void {
    this.wasm.set_col_sticky(this.gridId, col, edge);
    this.dirty = true;
  }

  /** Set cell-level sticky overrides. */
  setCellSticky(row: number, col: number, stickyRow: number, stickyCol: number): void {
    this.wasm.set_cell_sticky(this.gridId, row, col, stickyRow, stickyCol);
    this.dirty = true;
  }

  setDataSourceMode(mode: number): void {
    if (typeof this.wasm.set_data_source_mode === "function") {
      this.wasm.set_data_source_mode(this.gridId, mode);
    } else if (typeof this.wasm.set_data_mode === "function") {
      this.wasm.set_data_mode(this.gridId, mode);
    }
  }

  setDataMode(mode: number): void {
    this.setDataSourceMode(mode);
  }

  getDataSourceMode(): number {
    if (typeof this.wasm.get_data_source_mode === "function") {
      return Number(this.wasm.get_data_source_mode(this.gridId));
    }
    if (typeof this.wasm.get_data_mode === "function") {
      return Number(this.wasm.get_data_mode(this.gridId));
    }
    return 0;
  }

  getDataMode(): number {
    return this.getDataSourceMode();
  }

  setVirtualMode(enabled: boolean): void {
    if (typeof this.wasm.set_virtual_mode === "function") {
      this.wasm.set_virtual_mode(this.gridId, enabled ? 1 : 0);
    } else if (typeof this.wasm.set_virtual_data === "function") {
      this.wasm.set_virtual_data(this.gridId, enabled ? 1 : 0);
    }
  }

  setVirtualData(enabled: boolean): void {
    this.setVirtualMode(enabled);
  }

  getVirtualMode(): boolean {
    if (typeof this.wasm.get_virtual_mode === "function") {
      return Number(this.wasm.get_virtual_mode(this.gridId)) !== 0;
    }
    if (typeof this.wasm.get_virtual_data === "function") {
      return Number(this.wasm.get_virtual_data(this.gridId)) !== 0;
    }
    return false;
  }

  getVirtualData(): boolean {
    return this.getVirtualMode();
  }

  setPictureType(pictureType: number): void {
    if (typeof this.wasm.set_picture_type === "function") {
      this.wasm.set_picture_type(this.gridId, pictureType);
      this.dirty = true;
    }
  }

  getPictureType(): number {
    if (typeof this.wasm.get_picture_type === "function") {
      return Number(this.wasm.get_picture_type(this.gridId));
    }
    return 0;
  }

  getPicture(): Uint8Array {
    if (typeof this.wasm.get_picture === "function") {
      return this.wasm.get_picture(this.gridId) as Uint8Array;
    }
    return new Uint8Array();
  }

  setSortAscendingPicture(data: Uint8Array): void {
    if (typeof this.wasm.set_sort_ascending_picture === "function") {
      this.wasm.set_sort_ascending_picture(this.gridId, data);
      this.dirty = true;
    }
  }

  getSortAscendingPicture(): Uint8Array {
    if (typeof this.wasm.get_sort_ascending_picture === "function") {
      return this.wasm.get_sort_ascending_picture(this.gridId) as Uint8Array;
    }
    return new Uint8Array();
  }

  setSortDescendingPicture(data: Uint8Array): void {
    if (typeof this.wasm.set_sort_descending_picture === "function") {
      this.wasm.set_sort_descending_picture(this.gridId, data);
      this.dirty = true;
    }
  }

  getSortDescendingPicture(): Uint8Array {
    if (typeof this.wasm.get_sort_descending_picture === "function") {
      return this.wasm.get_sort_descending_picture(this.gridId) as Uint8Array;
    }
    return new Uint8Array();
  }

  private setIconPictureByApi(api: NonNullable<(typeof ICON_THEME_SLOT_META)[number]["pictureApi"]>, data: Uint8Array): void {
    if (api === "sort_ascending" && typeof this.wasm.set_sort_ascending_picture === "function") {
      this.wasm.set_sort_ascending_picture(this.gridId, data);
      return;
    }
    if (api === "sort_descending" && typeof this.wasm.set_sort_descending_picture === "function") {
      this.wasm.set_sort_descending_picture(this.gridId, data);
      return;
    }
    if (api === "tree_open" && typeof this.wasm.set_node_open_picture === "function") {
      this.wasm.set_node_open_picture(this.gridId, data);
      return;
    }
    if (api === "tree_closed" && typeof this.wasm.set_node_closed_picture === "function") {
      this.wasm.set_node_closed_picture(this.gridId, data);
      return;
    }
    if (api === "checkbox_checked" && typeof this.wasm.set_checkbox_checked_picture === "function") {
      this.wasm.set_checkbox_checked_picture(this.gridId, data);
      return;
    }
    if (api === "checkbox_unchecked" && typeof this.wasm.set_checkbox_unchecked_picture === "function") {
      this.wasm.set_checkbox_unchecked_picture(this.gridId, data);
      return;
    }
    if (
      api === "checkbox_indeterminate"
      && typeof this.wasm.set_checkbox_indeterminate_picture === "function"
    ) {
      this.wasm.set_checkbox_indeterminate_picture(this.gridId, data);
    }
  }

  private getIconPictureByApi(api: NonNullable<(typeof ICON_THEME_SLOT_META)[number]["pictureApi"]>): Uint8Array {
    if (api === "sort_ascending" && typeof this.wasm.get_sort_ascending_picture === "function") {
      return this.wasm.get_sort_ascending_picture(this.gridId) as Uint8Array;
    }
    if (api === "sort_descending" && typeof this.wasm.get_sort_descending_picture === "function") {
      return this.wasm.get_sort_descending_picture(this.gridId) as Uint8Array;
    }
    if (api === "tree_open" && typeof this.wasm.get_node_open_picture === "function") {
      return this.wasm.get_node_open_picture(this.gridId) as Uint8Array;
    }
    if (api === "tree_closed" && typeof this.wasm.get_node_closed_picture === "function") {
      return this.wasm.get_node_closed_picture(this.gridId) as Uint8Array;
    }
    if (api === "checkbox_checked" && typeof this.wasm.get_checkbox_checked_picture === "function") {
      return this.wasm.get_checkbox_checked_picture(this.gridId) as Uint8Array;
    }
    if (
      api === "checkbox_unchecked"
      && typeof this.wasm.get_checkbox_unchecked_picture === "function"
    ) {
      return this.wasm.get_checkbox_unchecked_picture(this.gridId) as Uint8Array;
    }
    if (
      api === "checkbox_indeterminate"
      && typeof this.wasm.get_checkbox_indeterminate_picture === "function"
    ) {
      return this.wasm.get_checkbox_indeterminate_picture(this.gridId) as Uint8Array;
    }
    return new Uint8Array();
  }

  setIconTheme(theme: VolvoxGridIconTheme): void {
    assertIconTheme(theme);
    let changed = false;

    if (theme.defaults?.textStyle != null) {
      const style = theme.defaults.textStyle;
      if (typeof this.wasm.patch_icon_theme_default_text_style === "function") {
        this.wasm.patch_icon_theme_default_text_style(
          this.gridId,
          style.fontName,
          style.fontSize,
          style.bold,
          style.italic,
          style.colorArgb,
        );
      }
      if (
        style.fontNames != null
        && typeof this.wasm.patch_icon_theme_default_font_names === "function"
      ) {
        this.wasm.patch_icon_theme_default_font_names(this.gridId, style.fontNames);
      }
      const nextDefaults: VolvoxGridIconThemeDefaults = {
        ...(this.iconThemeStyleCache.defaults ?? {}),
      };
      nextDefaults.textStyle = {
        ...(nextDefaults.textStyle ?? {}),
        ...(style.fontName != null ? { fontName: style.fontName } : {}),
        ...(style.fontNames != null ? { fontNames: [...style.fontNames] } : {}),
        ...(style.fontSize != null ? { fontSize: style.fontSize } : {}),
        ...(style.bold != null ? { bold: style.bold } : {}),
        ...(style.italic != null ? { italic: style.italic } : {}),
        ...(style.colorArgb != null ? { colorArgb: style.colorArgb } : {}),
      };
      this.iconThemeStyleCache.defaults = nextDefaults;
      changed = true;
    }

    if (theme.defaults?.layout != null) {
      const layout = theme.defaults.layout;
      if (typeof this.wasm.patch_icon_theme_default_layout === "function") {
        this.wasm.patch_icon_theme_default_layout(
          this.gridId,
          layout.align != null ? ICON_ALIGN_TO_WASM.get(layout.align) : undefined,
          layout.gapPx,
        );
      }
      const nextDefaults: VolvoxGridIconThemeDefaults = {
        ...(this.iconThemeStyleCache.defaults ?? {}),
      };
      nextDefaults.layout = {
        ...(nextDefaults.layout ?? {}),
        ...(layout.align != null ? { align: layout.align } : {}),
        ...(layout.gapPx != null ? { gapPx: layout.gapPx } : {}),
      };
      this.iconThemeStyleCache.defaults = nextDefaults;
      changed = true;
    }

    for (const [slotName, spec] of Object.entries(theme.slots) as Array<[VolvoxGridIconSlotName, VolvoxGridIconSpec]>) {
      const slotMeta = ICON_THEME_SLOT_BY_NAME.get(slotName);
      if (slotMeta == null) {
        continue;
      }
      const source = spec.source;
      if (source != null) {
        if (source.kind === "none") {
          if (typeof this.wasm.set_icon_theme_slot === "function") {
            this.wasm.set_icon_theme_slot(this.gridId, slotMeta.slotId, "");
          }
          if (slotMeta.pictureApi != null) {
            this.setIconPictureByApi(slotMeta.pictureApi, new Uint8Array());
          }
          changed = true;
        } else if (source.kind === "text") {
          if (typeof this.wasm.set_icon_theme_slot === "function") {
            this.wasm.set_icon_theme_slot(this.gridId, slotMeta.slotId, source.text.trim());
          }
          if (slotMeta.pictureApi != null) {
            this.setIconPictureByApi(slotMeta.pictureApi, new Uint8Array());
          }
          changed = true;
        } else if (source.kind === "image" && slotMeta.pictureApi != null) {
          const data = source.data;
          this.setIconPictureByApi(slotMeta.pictureApi, data);
          if (typeof this.wasm.set_icon_theme_slot === "function") {
            // Image source takes precedence for render when present.
            this.wasm.set_icon_theme_slot(this.gridId, slotMeta.slotId, "");
          }
          changed = true;
        }
      }

      if (spec.textStyle != null) {
        const style = spec.textStyle;
        if (typeof this.wasm.patch_icon_theme_slot_text_style === "function") {
          this.wasm.patch_icon_theme_slot_text_style(
            this.gridId,
            slotMeta.slotId,
            style.fontName,
            style.fontSize,
            style.bold,
            style.italic,
            style.colorArgb,
          );
        }
        if (
          style.fontNames != null
          && typeof this.wasm.patch_icon_theme_slot_font_names === "function"
        ) {
          this.wasm.patch_icon_theme_slot_font_names(
            this.gridId,
            slotMeta.slotId,
            style.fontNames,
          );
        }
        const nextSlot: Pick<VolvoxGridIconSpec, "textStyle" | "layout"> = {
          ...(this.iconThemeStyleCache.slots[slotName] ?? {}),
        };
        nextSlot.textStyle = {
          ...(nextSlot.textStyle ?? {}),
          ...(style.fontName != null ? { fontName: style.fontName } : {}),
          ...(style.fontNames != null ? { fontNames: [...style.fontNames] } : {}),
          ...(style.fontSize != null ? { fontSize: style.fontSize } : {}),
          ...(style.bold != null ? { bold: style.bold } : {}),
          ...(style.italic != null ? { italic: style.italic } : {}),
          ...(style.colorArgb != null ? { colorArgb: style.colorArgb } : {}),
        };
        this.iconThemeStyleCache.slots[slotName] = nextSlot;
        changed = true;
      }

      if (spec.layout != null) {
        const layout = spec.layout;
        if (typeof this.wasm.patch_icon_theme_slot_layout === "function") {
          this.wasm.patch_icon_theme_slot_layout(
            this.gridId,
            slotMeta.slotId,
            layout.align != null ? ICON_ALIGN_TO_WASM.get(layout.align) : undefined,
            layout.gapPx,
          );
        }
        const nextSlot: Pick<VolvoxGridIconSpec, "textStyle" | "layout"> = {
          ...(this.iconThemeStyleCache.slots[slotName] ?? {}),
        };
        nextSlot.layout = {
          ...(nextSlot.layout ?? {}),
          ...(layout.align != null ? { align: layout.align } : {}),
          ...(layout.gapPx != null ? { gapPx: layout.gapPx } : {}),
        };
        this.iconThemeStyleCache.slots[slotName] = nextSlot;
        changed = true;
      }
    }

    if (changed) {
      this.dirty = true;
    }
  }

  getIconTheme(): VolvoxGridIconTheme {
    const slots: Partial<Record<VolvoxGridIconSlotName, VolvoxGridIconSpec>> = {};
    for (const meta of ICON_THEME_SLOT_META) {
      if (meta.pictureApi != null) {
        const pictureData = this.getIconPictureByApi(meta.pictureApi);
        if (pictureData.length > 0) {
          slots[meta.name] = {
            source: {
              kind: "image",
              format: "png",
              data: new Uint8Array(pictureData),
            },
          };
          continue;
        }
      }

      if (typeof this.wasm.get_icon_theme_slot === "function") {
        const text = String(this.wasm.get_icon_theme_slot(this.gridId, meta.slotId) ?? "").trim();
        if (text.length > 0) {
          slots[meta.name] = {
            source: {
              kind: "text",
              text,
            },
          };
        }
      }

      const cachedStyle = this.iconThemeStyleCache.slots[meta.name];
      if (cachedStyle != null) {
        const base = slots[meta.name] ?? { source: { kind: "none" as const } };
        if (cachedStyle.textStyle != null) {
          const textStyle = { ...cachedStyle.textStyle };
          if (textStyle.fontNames != null) {
            textStyle.fontNames = [...textStyle.fontNames];
          }
          base.textStyle = textStyle;
        }
        if (cachedStyle.layout != null) {
          base.layout = { ...cachedStyle.layout };
        }
        slots[meta.name] = base;
      }
    }
    const out: VolvoxGridIconTheme = { slots };
    if (this.iconThemeStyleCache.defaults != null) {
      const defaults: VolvoxGridIconThemeDefaults = {};
      if (this.iconThemeStyleCache.defaults.textStyle != null) {
        const textStyle = { ...this.iconThemeStyleCache.defaults.textStyle };
        if (textStyle.fontNames != null) {
          textStyle.fontNames = [...textStyle.fontNames];
        }
        defaults.textStyle = textStyle;
      }
      if (this.iconThemeStyleCache.defaults.layout != null) {
        defaults.layout = { ...this.iconThemeStyleCache.defaults.layout };
      }
      if (defaults.textStyle != null || defaults.layout != null) {
        out.defaults = defaults;
      }
    }
    return out;
  }

  setIconSlots(slots: VolvoxGridIconSlots): void {
    const patchSlots: Partial<Record<VolvoxGridIconSlotName, VolvoxGridIconSpec>> = {};
    for (const meta of ICON_THEME_SLOT_META) {
      if (!Object.prototype.hasOwnProperty.call(slots, meta.name)) {
        continue;
      }
      const raw = slots[meta.name];
      if (typeof raw === "string" && raw.trim().length > 0) {
        patchSlots[meta.name] = {
          source: {
            kind: "text",
            text: raw.trim(),
          },
        };
      } else {
        patchSlots[meta.name] = {
          source: { kind: "none" },
        };
      }
    }
    this.setIconTheme({ slots: patchSlots });
  }

  setIconThemeSlots(slots: VolvoxGridIconThemeSlots): void {
    this.setIconSlots(slots);
  }

  getIconSlots(): VolvoxGridIconSlots {
    const out: VolvoxGridIconSlots = {};
    const theme = this.getIconTheme();
    for (const [slotName, spec] of Object.entries(theme.slots) as Array<[VolvoxGridIconSlotName, VolvoxGridIconSpec]>) {
      if (spec.source?.kind === "text") {
        out[slotName] = spec.source.text;
      }
    }
    return out;
  }

  getIconThemeSlots(): VolvoxGridIconThemeSlots {
    return this.getIconSlots();
  }

  setColDropdownItems(col: number, items: string): void {
    if (typeof this.wasm.set_col_dropdown_items === "function") {
      this.wasm.set_col_dropdown_items(this.gridId, col, items);
    } else {
      this.wasm.set_col_combo_list(this.gridId, col, items);
    }
    this.dirty = true;
  }

  setColComboList(col: number, list: string): void {
    this.setColDropdownItems(col, list);
  }

  setCellDropdownItems(row: number, col: number, items: string): void {
    if (typeof this.wasm.set_cell_dropdown_items === "function") {
      this.wasm.set_cell_dropdown_items(this.gridId, row, col, items);
    } else {
      this.wasm.set_cell_combo_list(this.gridId, row, col, items);
    }
    this.dirty = true;
  }

  setCellComboList(row: number, col: number, list: string): void {
    this.setCellDropdownItems(row, col, list);
  }

  set flingImpulseGain(gain: number) {
    if (typeof this.wasm.set_fling_impulse_gain === "function") {
      this.wasm.set_fling_impulse_gain(this.gridId, gain);
    }
  }

  set flingFriction(friction: number) {
    if (typeof this.wasm.set_fling_friction === "function") {
      this.wasm.set_fling_friction(this.gridId, friction);
    }
  }

  // ── Renderer Mode ─────────────────────────────────────────────────────

  /**
   * Set GPU present mode using proto RenderConfig.present_mode.
   *
   * 0=AUTO, 1=FIFO, 2=MAILBOX, 3=IMMEDIATE
   */
  get presentMode(): number {
    return this._presentMode;
  }

  set presentMode(mode: number) {
    const next = Number.isFinite(mode) ? Math.max(0, Math.trunc(mode)) : 0;
    this._presentMode = next;

    if (typeof this.wasm.volvox_grid_configure === "function") {
      try {
        const cfg = pbEncodeRenderPresentModeConfig(next);
        this.wasm.volvox_grid_configure(BigInt(this.gridId), cfg);
      } catch (e) {
        console.warn("VolvoxGrid: failed to apply PresentMode via proto config", e);
      }
    }

    if (this.gpuCanvas && typeof this.wasm.gpu_configure_surface === "function") {
      const w = Math.max(1, this.gpuCanvas.width || this.canvas.width || 1);
      const h = Math.max(1, this.gpuCanvas.height || this.canvas.height || 1);
      this.wasm.gpu_configure_surface(this.gpuCanvas, w, h, this._presentMode);
    }

    this.dirty = true;
  }

  /** Set renderer mode: 0=AUTO, 1=CPU, 2=GPU */
  get rendererMode(): number {
    if (typeof this.wasm.get_renderer_mode === "function") {
      return Number(this.wasm.get_renderer_mode(this.gridId));
    }
    return 0;
  }

  set rendererMode(mode: number) {
    if (typeof this.wasm.set_renderer_mode === "function") {
      this.wasm.set_renderer_mode(this.gridId, mode);
    }
    if (mode >= 2 && this.gpuCanvas) {
      this.useGpu = true;
    } else if (mode === 1) {
      this.useGpu = false;
    }
    this.dirty = true;
  }

  get rendererBackend(): number {
    return this.rendererMode;
  }

  set rendererBackend(mode: number) {
    this.rendererMode = mode;
  }

  /** Check if GPU renderer is available in this build. */
  hasGpuRenderer(): boolean {
    if (typeof this.wasm.has_gpu_renderer === "function") {
      return Boolean(this.wasm.has_gpu_renderer());
    }
    return false;
  }

  /**
   * Attempt to initialise GPU rendering via WebGPU.
   *
   * Creates a second (overlay) canvas for the WebGPU surface so that the
   * original canvas keeps its 2D context and CPU<->GPU toggling works at
   * runtime via the `rendererMode` property.
   *
   * On failure the grid falls back to the CPU path transparently.
   */
  async tryInitGpu(): Promise<boolean> {
    try {
      this.commitPendingSize();
      if (!this.wasm.has_gpu_renderer()) {
        console.info("VolvoxGrid: GPU feature not compiled in");
        return false;
      }
      if (this.rendererMode === 1) return false; // CPU-only by user choice

      if (typeof navigator === "undefined" || !("gpu" in navigator)) {
        console.warn(
          "VolvoxGrid: WebGPU not available (navigator.gpu missing).\n" +
          "  Chrome Linux: enable chrome://flags/#enable-unsafe-webgpu\n" +
          "  Also verify Vulkan support: chrome://gpu",
        );
        return false;
      }

      const ok = await this.wasm.init_gpu();
      if (!ok) return false;

      // A canvas can only have one context type (2D or WebGPU).  Create a
      // separate canvas for the GPU surface so CPU<->GPU toggling works.
      const gpuCanvas = document.createElement("canvas");
      const w = Math.max(1, this.canvas.width);
      const h = Math.max(1, this.canvas.height);
      gpuCanvas.width = w;
      gpuCanvas.height = h;
      // Overlay the GPU canvas exactly on top of the original canvas.
      // Use the canvas itself as the positioning anchor so container
      // padding / borders don't cause a size mismatch.
      gpuCanvas.style.position = "absolute";
      gpuCanvas.style.pointerEvents = "none";
      gpuCanvas.style.display = "none";

      const parent = this.ensureOverlayParent();
      if (parent) {
        parent.appendChild(gpuCanvas);
      }
      this.gpuCanvas = gpuCanvas;
      this.syncPresentCanvasPosition();

      const configured = this.wasm.gpu_configure_surface(gpuCanvas, w, h, this._presentMode);
      if (!configured) {
        gpuCanvas.remove();
        this.gpuCanvas = null;
        this.useGpu = false;
        return false;
      }

      this.useGpu = true;
      this.dirty = true;
      return true;
    } catch (e) {
      console.warn("VolvoxGrid: GPU init failed, falling back to CPU", e);
      this.useGpu = false;
      return false;
    }
  }

  private ensureOverlayParent(): HTMLElement | null {
    const parent = this.canvas.parentElement;
    if (!parent) {
      return null;
    }
    if (getComputedStyle(parent).position === "static") {
      parent.style.position = "relative";
    }
    return parent;
  }

  private ensureCpuCanvasOverlay(): void {
    if (this.cpuCanvas) {
      return;
    }
    const parent = this.ensureOverlayParent();
    if (!parent) {
      return;
    }
    const cpuCanvas = document.createElement("canvas");
    cpuCanvas.style.position = "absolute";
    cpuCanvas.style.pointerEvents = "none";
    cpuCanvas.style.display = "block";
    cpuCanvas.width = Math.max(1, this.canvas.width || 1);
    cpuCanvas.height = Math.max(1, this.canvas.height || 1);
    parent.appendChild(cpuCanvas);
    this.cpuCanvas = cpuCanvas;
    this.ctx = null;
    this.canvasOpacityBeforeOverlay = this.canvas.style.opacity;
    this.canvas.style.opacity = "0";
    this.syncPresentCanvasPosition();
  }

  private getCpuSurfaceCanvas(): HTMLCanvasElement {
    return this.cpuCanvas ?? this.canvas;
  }

  /** Lazily acquire the 2D context (CPU fallback path). */
  private ensureCtx(): CanvasRenderingContext2D {
    if (!this.ctx) {
      this.ensureCpuCanvasOverlay();
      const ctx = this.getCpuSurfaceCanvas().getContext("2d", { willReadFrequently: false });
      if (!ctx) {
        throw new Error("Failed to get 2d context from canvas");
      }
      this.ctx = ctx;
    }
    return this.ctx;
  }

  /** Enable or disable the debug overlay. */
  get debugOverlay(): boolean {
    if (typeof this.wasm.get_debug_overlay === "function") {
      return Boolean(this.wasm.get_debug_overlay(this.gridId));
    }
    return false;
  }

  set debugOverlay(enabled: boolean) {
    if (typeof this.wasm.set_debug_overlay === "function") {
      this.wasm.set_debug_overlay(this.gridId, enabled);
      this.dirty = true;
    }
  }

  /** Enable or disable scroll blit. */
  get scrollBlit(): boolean {
    if (typeof this.wasm.get_scroll_blit === "function") {
      return Boolean(this.wasm.get_scroll_blit(this.gridId));
    }
    return false;
  }

  set scrollBlit(enabled: boolean) {
    if (typeof this.wasm.set_scroll_blit === "function") {
      this.wasm.set_scroll_blit(this.gridId, enabled);
      this.dirty = true;
    }
  }

  get animationEnabled(): boolean {
    if (typeof this.wasm.get_animation_enabled === "function") {
      this.animationEnabledValue = Boolean(this.wasm.get_animation_enabled(this.gridId));
    }
    return this.animationEnabledValue;
  }

  /** Enable or disable layout animation. */
  set animationEnabled(enabled: boolean) {
    this.animationEnabledValue = Boolean(enabled);
    if (typeof this.wasm.set_animation_enabled === "function") {
      this.wasm.set_animation_enabled(
        this.gridId,
        this.animationEnabledValue,
        this.animationDurationMsValue,
      );
      this.dirty = true;
    }
  }

  get animationDurationMs(): number {
    return this.animationDurationMsValue;
  }

  set animationDurationMs(durationMs: number) {
    this.animationDurationMsValue = Math.max(0, Math.trunc(durationMs));
    if (typeof this.wasm.set_animation_enabled === "function") {
      this.wasm.set_animation_enabled(
        this.gridId,
        this.animationEnabled,
        this.animationDurationMsValue,
      );
      this.dirty = true;
    }
  }

  get textLayoutCacheCap(): number {
    if (typeof this.wasm.get_text_layout_cache_cap === "function") {
      this.textLayoutCacheCapValue = Number(this.wasm.get_text_layout_cache_cap(this.gridId));
    }
    return this.textLayoutCacheCapValue;
  }

  /** Set the text layout cache capacity. */
  set textLayoutCacheCap(cap: number) {
    this.textLayoutCacheCapValue = Math.max(0, Math.trunc(cap));
    if (typeof this.wasm.set_text_layout_cache_cap === "function") {
      this.wasm.set_text_layout_cache_cap(this.gridId, this.textLayoutCacheCapValue);
      this.dirty = true;
    }
  }

  getVisibleRowRange(): { first: number; last: number } {
    if (typeof this.wasm.get_visible_row_start === "function"
      && typeof this.wasm.get_visible_row_end === "function") {
      const first = Number(this.wasm.get_visible_row_start(this.gridId));
      const last = Number(this.wasm.get_visible_row_end(this.gridId));
      return { first, last };
    }
    const row = this.cursorRow;
    return { first: row, last: row };
  }

  hasCell(row: number, col: number): boolean {
    if (typeof this.wasm.has_cell === "function") {
      return Number(this.wasm.has_cell(this.gridId, row, col)) !== 0;
    }
    return this.getCellText(row, col).length > 0;
  }

  clearCellRange(row1: number, col1: number, row2: number, col2: number): void {
    if (typeof this.wasm.clear_cell_range === "function") {
      this.wasm.clear_cell_range(this.gridId, row1, col1, row2, col2);
      this.dirty = true;
    }
  }

  /**
   * Pull queued GridEvent protobuf payloads from WASM EventStream.
   *
   * Returns raw `GridEvent` protobuf bytes. Callers can decode with their
   * generated protobuf runtime. Raw-stream consumers that need cancellation
   * must first call `setEventDecisionEnabled(true)` and then respond with
   * `sendRawEventDecision(...)` or `sendEventDecision(...)`.
   */
  drainEventStreamRaw(maxEvents: number = 256): Uint8Array[] {
    if (typeof this.wasm.volvox_grid_stream_open !== "function"
      || typeof this.wasm.volvox_grid_stream_send !== "function"
      || typeof this.wasm.volvox_grid_stream_recv !== "function"
      || typeof this.wasm.volvox_grid_stream_close !== "function") {
      return [];
    }

    const handle = this.wasm.volvox_grid_stream_open(
      "/volvoxgrid.v1.VolvoxGridService/EventStream",
    ) as unknown;
    if (!isValidStreamHandle(handle)) {
      return [];
    }

    try {
      const request = pbEncodeGridHandleRequest(this.gridId);
      const sendStatus = Number(this.wasm.volvox_grid_stream_send(handle, request));
      if (sendStatus !== 0) {
        return [];
      }
      if (typeof this.wasm.volvox_grid_stream_close_send === "function") {
        this.wasm.volvox_grid_stream_close_send(handle);
      }

      const out: Uint8Array[] = [];
      const limit = Math.max(1, Math.trunc(maxEvents));
      for (let i = 0; i < limit; i += 1) {
        const frame = this.wasm.volvox_grid_stream_recv(handle) as Uint8Array;
        if (!(frame instanceof Uint8Array) || frame.length < 1) {
          break;
        }
        const status = decodeSignedStatus(Number(frame[0]));
        if (status === 0) {
          out.push(frame.slice(1));
          continue;
        }
        if (status < 0) {
          throwFfiErrorPayload(frame.slice(1));
        }
        if (status === STREAM_STATUS_EOF || status === STREAM_STATUS_PENDING) {
          break;
        }
        break;
      }
      return out;
    } finally {
      this.wasm.volvox_grid_stream_close(handle);
    }
  }

  private hasCancelableEventListeners(): boolean {
    return this.beforeEditListener != null
      || this.cellEditValidatingListener != null
      || this.beforeSortListener != null;
  }

  private decisionChannelRequested(): boolean {
    return this.manualEventDecisionEnabled || this.hasCancelableEventListeners();
  }

  /** Enable EventDecision support for raw `drainEventStreamRaw()` consumers. */
  setEventDecisionEnabled(enabled: boolean): void {
    this.manualEventDecisionEnabled = Boolean(enabled);
    this.syncCancelableEventDecisionSupport();
  }

  private syncCancelableEventDecisionSupport(): void {
    if (typeof this.wasm.set_event_decision_enabled !== "function") {
      return;
    }
    this.wasm.set_event_decision_enabled(this.gridId, this.decisionChannelRequested());
  }

  /** Send a decision for a cancelable raw event by event id. */
  sendEventDecision(eventId: bigint, cancel: boolean): boolean {
    if (typeof this.wasm.send_event_decision !== "function") {
      return false;
    }
    if (typeof eventId !== "bigint" || eventId <= 0n) {
      return false;
    }
    this.wasm.send_event_decision(this.gridId, eventId, cancel);
    return true;
  }

  /** Decode a raw `GridEvent` frame and send its cancel decision. */
  sendRawEventDecision(rawEvent: Uint8Array, cancel: boolean): boolean {
    const decoded = pbDecodeGridEventEnvelope(rawEvent);
    if (decoded == null || decoded.eventId === 0n) {
      return false;
    }
    return this.sendEventDecision(decoded.eventId, cancel);
  }

  private dispatchCancelableGridEvent(
    decoded: { eventId: bigint; eventField: number; payload: Uint8Array },
    rawEvent: Uint8Array,
  ): boolean {
    try {
      if (decoded.eventField === GRID_EVENT_BEFORE_EDIT) {
        const payload = pbDecodeBeforeEditPayload(decoded.payload);
        const details: VolvoxGridBeforeEditDetails = {
          eventId: decoded.eventId,
          rawEvent,
          row: payload.row,
          col: payload.col,
          cancel: false,
        };
        this.beforeEditListener?.(details);
        return details.cancel;
      }

      if (decoded.eventField === GRID_EVENT_CELL_EDIT_VALIDATE) {
        const payload = pbDecodeCellEditValidatePayload(decoded.payload);
        const details: VolvoxGridCellEditValidatingDetails = {
          eventId: decoded.eventId,
          rawEvent,
          row: payload.row,
          col: payload.col,
          editText: payload.editText,
          cancel: false,
        };
        this.cellEditValidatingListener?.(details);
        return details.cancel;
      }

      if (decoded.eventField === GRID_EVENT_BEFORE_SORT) {
        const payload = pbDecodeBeforeSortPayload(decoded.payload);
        const details: VolvoxGridBeforeSortDetails = {
          eventId: decoded.eventId,
          rawEvent,
          col: payload.col,
          cancel: false,
        };
        this.beforeSortListener?.(details);
        return details.cancel;
      }
    } catch (error) {
      console.error("VolvoxGrid cancelable event listener failed", error);
    }

    return false;
  }

  /** Flush pending cancelable event decisions queued by low-level WASM/service calls. */
  flushPendingEventDecisions(): boolean {
    return this.flushCancelableEventDecisions();
  }

  private flushCancelableEventDecisions(): boolean {
    if (typeof this.wasm.take_pending_decision_event !== "function"
      || typeof this.wasm.send_event_decision !== "function") {
      return false;
    }

    let canceled = false;
    for (let i = 0; i < 32; i += 1) {
      const rawEvent = this.wasm.take_pending_decision_event(this.gridId) as Uint8Array;
      if (!(rawEvent instanceof Uint8Array) || rawEvent.length === 0) {
        break;
      }

      const decoded = pbDecodeGridEventEnvelope(rawEvent);
      if (decoded == null || decoded.eventId === 0n) {
        continue;
      }

      const shouldCancel = this.dispatchCancelableGridEvent(decoded, rawEvent);
      canceled = canceled || shouldCancel;
      this.wasm.send_event_decision(this.gridId, decoded.eventId, shouldCancel);
    }
    return canceled;
  }

  /** Proto clear API (scope/region enums). */
  clear(scope: number = 0, region: number = 0): void {
    if (typeof this.wasm.volvox_grid_clear === "function") {
      this.wasm.volvox_grid_clear(BigInt(this.gridId), scope, region);
      this.dirty = true;
      return;
    }
    this.clearCellRange(0, 0, Math.max(0, this.rowCount - 1), Math.max(0, this.colCount - 1));
  }

  // ── Sort ─────────────────────────────────────────────────────────────

  sort(order: number, col: number): void {
    this.wasm.sort(this.gridId, order, col);
    this.dirty = true;
  }

  sortMulti(cols: number[], orders: number[]): void {
    this.wasm.sort_multi(this.gridId, new Int32Array(cols), new Int32Array(orders));
    this.dirty = true;
  }

  /** Expand/collapse tree rows to [level]. */
  outline(level: number): void {
    if (typeof this.wasm.volvox_grid_outline === "function") {
      this.wasm.volvox_grid_outline(BigInt(this.gridId), level);
      this.dirty = true;
    }
  }

  /** Auto-size a range of columns. */
  autoSize(colFrom: number = 0, colTo: number = -1, equal: boolean = false, maxWidth: number = 0): void {
    if (typeof this.wasm.volvox_grid_auto_size === "function") {
      this.wasm.volvox_grid_auto_size(BigInt(this.gridId), colFrom, colTo, equal, maxWidth);
      this.dirty = true;
      return;
    }

    const first = Math.max(0, Math.trunc(colFrom));
    const last = colTo < 0 ? this.colCount - 1 : Math.min(this.colCount - 1, Math.trunc(colTo));
    if (last < first) return;
    for (let c = first; c <= last; c += 1) {
      this.autoResizeCol(c);
    }
  }

  /** Find a row by plain text in [col]. Returns -1 if not found. */
  findRowByText(
    text: string,
    options: { col: number; startRow?: number; caseSensitive?: boolean; fullMatch?: boolean },
  ): number {
    const startRow = options.startRow ?? 0;
    const caseSensitive = options.caseSensitive ?? false;
    const fullMatch = options.fullMatch ?? false;

    if (typeof this.wasm.volvox_grid_find_pb === "function") {
      const req = pbEncodeFindTextRequest(
        this.gridId,
        options.col,
        startRow,
        text,
        caseSensitive,
        fullMatch,
      );
      const resp = this.wasm.volvox_grid_find_pb(req) as Uint8Array;
      return pbDecodeFindRow(resp);
    }

    const needle = caseSensitive ? text : text.toLowerCase();
    for (let r = Math.max(0, startRow); r < this.rowCount; r += 1) {
      const cell = this.getCellText(r, options.col);
      const value = caseSensitive ? cell : cell.toLowerCase();
      if (fullMatch ? value === needle : value.includes(needle)) {
        return r;
      }
    }
    return -1;
  }

  /** Find a row by regex in [col]. Returns -1 if not found. */
  findRowByRegex(pattern: string, options: { col: number; startRow?: number }): number {
    const startRow = options.startRow ?? 0;

    if (typeof this.wasm.volvox_grid_find_pb === "function") {
      const req = pbEncodeFindRegexRequest(this.gridId, options.col, startRow, pattern);
      const resp = this.wasm.volvox_grid_find_pb(req) as Uint8Array;
      return pbDecodeFindRow(resp);
    }

    let rx: RegExp;
    try {
      rx = new RegExp(pattern);
    } catch {
      return -1;
    }
    for (let r = Math.max(0, startRow); r < this.rowCount; r += 1) {
      if (rx.test(this.getCellText(r, options.col))) {
        return r;
      }
    }
    return -1;
  }

  /** Query node metadata for [row]. */
  getNode(row: number, relation?: number): VolvoxGridNodeInfo | null {
    if (typeof this.wasm.volvox_grid_get_node_pb === "function") {
      const req = pbEncodeGetNodeRequest(this.gridId, row, relation);
      const resp = this.wasm.volvox_grid_get_node_pb(req) as Uint8Array;
      return pbDecodeNodeInfo(resp);
    }
    return null;
  }

  /** Aggregate over a rectangular range. */
  aggregate(type: number, row1: number, col1: number, row2: number, col2: number): number {
    if (typeof this.wasm.volvox_grid_aggregate === "function") {
      const resp = this.wasm.volvox_grid_aggregate(
        BigInt(this.gridId),
        type,
        row1,
        col1,
        row2,
        col2,
      ) as Uint8Array;
      return pbDecodeAggregateValue(resp);
    }

    let count = 0;
    let sum = 0;
    let min = Number.POSITIVE_INFINITY;
    let max = Number.NEGATIVE_INFINITY;
    for (let r = row1; r <= row2; r += 1) {
      for (let c = col1; c <= col2; c += 1) {
        const n = Number(this.getCellText(r, c));
        if (!Number.isFinite(n)) continue;
        count += 1;
        sum += n;
        if (n < min) min = n;
        if (n > max) max = n;
      }
    }
    if (type === 2) return sum; // AGG_SUM
    if (type === 4) return count; // AGG_COUNT
    if (type === 5) return count > 0 ? sum / count : Number.NaN; // AGG_AVERAGE
    if (type === 6) return count > 0 ? max : Number.NaN; // AGG_MAX
    if (type === 7) return count > 0 ? min : Number.NaN; // AGG_MIN
    return Number.NaN;
  }

  /** Return merged range containing [row, col]. */
  getMergedRange(row: number, col: number): VolvoxGridCellRange | null {
    if (typeof this.wasm.volvox_grid_get_merged_range === "function") {
      const resp = this.wasm.volvox_grid_get_merged_range(
        BigInt(this.gridId),
        row,
        col,
      ) as Uint8Array;
      return pbDecodeCellRange(resp);
    }
    return { row1: row, col1: col, row2: row, col2: col };
  }

  // ── User resizing / freezing ────────────────────────────────────────

  setAutoSizeMouse(enabled: boolean): void {
    this.wasm.set_auto_size_mouse(this.gridId, enabled ? 1 : 0);
  }

  getAutoSizeMouse(): boolean {
    return this.wasm.get_auto_size_mouse(this.gridId) !== 0;
  }

  autoResizeCol(col: number): void {
    this.wasm.auto_resize_col(this.gridId, col);
    this.dirty = true;
  }

  autoResizeRow(row: number): void {
    this.wasm.auto_resize_row(this.gridId, row);
    this.dirty = true;
  }

  // ── FormatString / ColFormat / EditMask ──────────────────────────────

  /** Pipe-delimited column setup: "<Name|>Amount;120|^Status" */
  setFormatString(fmt: string): void {
    this.wasm.set_format_string(this.gridId, fmt);
  }

  getFormatString(): string {
    return this.wasm.get_format_string(this.gridId);
  }

  applyFormatString(): void {
    this.wasm.apply_format_string(this.gridId);
    this.dirty = true;
  }

  /** Display format for a column (e.g. "$#,##0.00", "0.0%") */
  setColFormat(col: number, format: string): void {
    this.wasm.set_col_format(this.gridId, col, format);
    this.dirty = true;
  }

  getColFormat(col: number): string {
    return this.wasm.get_col_format(this.gridId, col);
  }

  setColProgressColor(col: number, color: number): void {
    if (typeof this.wasm.set_col_progress_color === "function") {
      this.wasm.set_col_progress_color(this.gridId, col, color);
    } else {
      this.wasm.set_col_flood_color(this.gridId, col, color);
    }
    this.dirty = true;
  }

  setColFloodColor(col: number, color: number): void {
    this.setColProgressColor(col, color);
  }

  /** Global edit mask (e.g. "(###) ###-####") */
  setEditMask(mask: string): void {
    this.wasm.set_edit_mask(this.gridId, mask);
  }

  getEditMask(): string {
    return this.wasm.get_edit_mask(this.gridId);
  }

  /** Per-column edit mask */
  setColEditMask(col: number, mask: string): void {
    this.wasm.set_col_edit_mask(this.gridId, col, mask);
  }

  // ── AddItem / RemoveItem ────────────────────────────────────────────

  /** Insert a row with tab-delimited text. atRow = -1 to append at end. */
  addItem(text: string, atRow: number = -1): void {
    this.wasm.add_item(this.gridId, text, atRow);
    this.dirty = true;
  }

  /** Remove a row by grid row index. */
  removeItem(row: number): void {
    this.wasm.remove_item(this.gridId, row);
    this.dirty = true;
  }

  // ── Display text ────────────────────────────────────────────────────

  /** Get display text (applies ColFormat and combo translation). */
  getDisplayText(row: number, col: number): string {
    return this.wasm.get_display_text(this.gridId, row, col);
  }

  // ── Invalidation ─────────────────────────────────────────────────────

  invalidate(): void {
    this.wasm.invalidate(this.gridId);
    this.dirty = true;
  }

  /** Suppress internal dirty-marking during bulk cell updates.
   *  Call setRedraw(false) before a batch, then setRedraw(true) + invalidate() after. */
  setRedraw(on: boolean): void {
    if (typeof this.wasm.volvox_grid_set_redraw === "function") {
      this.wasm.volvox_grid_set_redraw(BigInt(this.gridId), on);
      return;
    }
    if (typeof this.wasm.set_redraw === "function") {
      this.wasm.set_redraw(this.gridId, on);
    }
  }

  get scrollBars(): number {
    if (typeof this.wasm.get_scroll_bars === "function") {
      this.scrollBarsValue = Number(this.wasm.get_scroll_bars(this.gridId));
    }
    return this.scrollBarsValue;
  }

  /** Set scrollbar visibility: 0=none, 1=horizontal, 2=vertical, 3=both */
  set scrollBars(mode: number) {
    this.scrollBarsValue = Math.trunc(mode);
    if (typeof this.wasm.set_scroll_bars === "function") {
      this.wasm.set_scroll_bars(this.gridId, this.scrollBarsValue);
    }
  }

  /** Force a full engine repaint. */
  refresh(): void {
    if (typeof this.wasm.volvox_grid_refresh === "function") {
      this.wasm.volvox_grid_refresh(BigInt(this.gridId));
    } else {
      this.invalidate();
    }
    this.dirty = true;
  }

  /** Force synchronous layout calculation. */
  ensureLayout(): void {
    this.commitPendingSize();
    if (typeof this.wasm.render === "function") {
      // Calling render with 0,0 usually triggers ensure_layout in the engine
      // without actually painting pixels if the viewport is empty.
      this.wasm.render(this.gridId, this.canvas.width || 1, this.canvas.height || 1);
    }
  }

  /** Notify engine that viewport dimensions changed. */
  resizeViewport(width: number, height: number): void {
    if (typeof this.wasm.volvox_grid_resize_viewport === "function") {
      this.wasm.volvox_grid_resize_viewport(BigInt(this.gridId), width, height);
      this.dirty = true;
      return;
    }
    this.setRenderResolution(width, height);
  }

  /** Load a built-in demo by name ("sales", "hierarchy", "stress"). */
  loadDemo(demo: string): void {
    if (typeof this.wasm.volvox_grid_load_demo === "function") {
      this.wasm.volvox_grid_load_demo(BigInt(this.gridId), demo);
      this.dirty = true;
    }
  }

  /** Archive snapshots (0=save, 1=load, 2=delete, 3=list). */
  archive(action: number, name: string = "", data: Uint8Array = new Uint8Array()): Uint8Array {
    if (typeof this.wasm.volvox_grid_archive === "function") {
      return this.wasm.volvox_grid_archive(BigInt(this.gridId), name, action, data) as Uint8Array;
    }
    return new Uint8Array();
  }

  /**
   * Render the grid to a sequence of printable page images (PNG).
   * Returns a promise that resolves to a list of pages.
   */
  async printGrid(options: {
    orientation?: number;
    marginLeft?: number;
    marginTop?: number;
    marginRight?: number;
    marginBottom?: number;
    header?: string;
    footer?: string;
    showPageNumbers?: boolean;
  }): Promise<{ pageNumber: number; imageData: Uint8Array; width: number; height: number }[]> {
    const req: number[] = [];
    req.push(...pbEncodeTag(1, 0), ...pbEncodeInt64(BigInt(this.gridId)));
    if (options.orientation !== undefined) req.push(...pbEncodeTag(2, 0), ...pbEncodeInt32(options.orientation));
    if (options.marginLeft !== undefined) req.push(...pbEncodeTag(3, 0), ...pbEncodeInt32(options.marginLeft));
    if (options.marginTop !== undefined) req.push(...pbEncodeTag(4, 0), ...pbEncodeInt32(options.marginTop));
    if (options.marginRight !== undefined) req.push(...pbEncodeTag(5, 0), ...pbEncodeInt32(options.marginRight));
    if (options.marginBottom !== undefined) req.push(...pbEncodeTag(6, 0), ...pbEncodeInt32(options.marginBottom));
    if (options.header !== undefined) req.push(...pbEncodeStringField(7, options.header));
    if (options.footer !== undefined) req.push(...pbEncodeStringField(8, options.footer));
    if (options.showPageNumbers !== undefined) req.push(...pbEncodeTag(9, 0), ...pbEncodeBool(options.showPageNumbers));
    const requestBytes = new Uint8Array(req);

    if (typeof this.wasm.volvox_grid_print_pb === "function") {
      const response = this.wasm.volvox_grid_print_pb(requestBytes) as Uint8Array;
      if (!(response instanceof Uint8Array) || response.length === 0) {
        return [];
      }
      return pbDecodePrintResponse(response);
    }

    if (typeof this.wasm.volvox_grid_stream_open !== "function"
      || typeof this.wasm.volvox_grid_stream_send !== "function"
      || typeof this.wasm.volvox_grid_stream_recv !== "function"
      || typeof this.wasm.volvox_grid_stream_close !== "function") {
      return [];
    }

    const handle = this.wasm.volvox_grid_stream_open(
      "/volvoxgrid.v1.VolvoxGridService/Print",
    ) as unknown;
    if (!isValidStreamHandle(handle)) {
      return [];
    }

    try {
      const sendStatus = Number(this.wasm.volvox_grid_stream_send(handle, requestBytes));
      if (sendStatus !== 0) return [];
      if (typeof this.wasm.volvox_grid_stream_close_send === "function") {
        this.wasm.volvox_grid_stream_close_send(handle);
      }

      const pages: { pageNumber: number; imageData: Uint8Array; width: number; height: number }[] = [];
      while (true) {
        const frame = this.wasm.volvox_grid_stream_recv(handle) as Uint8Array;
        if (!(frame instanceof Uint8Array) || frame.length < 1) break;

        const status = decodeSignedStatus(Number(frame[0]));
        if (status === STREAM_STATUS_DATA) {
          const data = frame.slice(1);
          const decoded = pbDecodePrintResponse(data);
          if (decoded.length > 0) {
            pages.push(...decoded);
            continue;
          }
          const single = pbDecodePrintPage(data);
          if (single) {
            pages.push(single);
          }
          continue;
        }
        if (status < 0) {
          throwFfiErrorPayload(frame.slice(1));
        }
        if (status === STREAM_STATUS_EOF || status === STREAM_STATUS_PENDING) {
          break;
        }
        break;
      }
      return pages;
    } finally {
      this.wasm.volvox_grid_stream_close(handle);
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  /**
   * Switch this view to another existing engine-side grid ID.
   *
   * This keeps the same canvas/render loop/event wiring and only changes
   * which native grid instance receives input and render calls.
   */
  useGrid(id: number): void {
    const nextId = Math.trunc(Number(id));
    if (!Number.isFinite(nextId) || nextId <= 0 || nextId === this.gridId) {
      return;
    }
    if (typeof this.wasm.set_event_decision_enabled === "function") {
      this.wasm.set_event_decision_enabled(this.gridId, false);
    }
    if (this.wasm.is_editing(this.gridId)) {
      this.wasm.cancel_edit(this.gridId);
    }
    // Stop fling on the old grid before switching
    if (typeof this.wasm.set_fling_enabled === "function") {
      this.wasm.set_fling_enabled(this.gridId, 0);
    }
    this.hideHostEditors(false);
    this.gridId = nextId;
    if (this._presentMode !== 0) {
      this.presentMode = this._presentMode;
    }
    // Re-enable fling on the new grid
    if (typeof this.wasm.set_fling_enabled === "function") {
      this.wasm.set_fling_enabled(this.gridId, 1);
    }
    this.syncCancelableEventDecisionSupport();
    this.dirty = true;
  }

  destroy(): void {
    this.destroyed = true;
    if (typeof this.wasm.set_event_decision_enabled === "function") {
      this.wasm.set_event_decision_enabled(this.gridId, false);
    }
    if (this.animFrame) {
      cancelAnimationFrame(this.animFrame);
      this.animFrame = 0;
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
      this.resizeObserver = null;
    }
    this.removeEventListeners();
    this.removeHostEditors();
    this.invalidateRenderCache();
    if (this.cpuCanvas) {
      this.cpuCanvas.remove();
      this.cpuCanvas = null;
    }
    if (this.canvasOpacityBeforeOverlay != null) {
      this.canvas.style.opacity = this.canvasOpacityBeforeOverlay;
      this.canvasOpacityBeforeOverlay = null;
    }
    if (this.gpuCanvas) {
      this.gpuCanvas.remove();
      this.gpuCanvas = null;
    }
    this.wasm.destroy_grid(this.gridId);
  }

  // ── Internal: rendering ──────────────────────────────────────────────

  private syncSize(applyImmediately: boolean = false): void {
    this.ensureCpuCanvasOverlay();
    // Re-sample DPR on each resize (user may drag between monitors).
    const rawDpr = window.devicePixelRatio || 1;
    const deviceDpr = Number.isFinite(rawDpr) && rawDpr > 0 ? rawDpr : 1;

    // Apply maxDpr cap — trades sharpness for performance.
    const effectiveDpr =
      this._maxDpr > 0 ? Math.min(deviceDpr, this._maxDpr) : deviceDpr;

    // Use clientWidth/clientHeight (CSS pixels) for the layout size,
    // then multiply by effectiveDpr for the actual canvas buffer.
    const cssW = Math.max(1, this.canvas.clientWidth);
    const cssH = Math.max(1, this.canvas.clientHeight);
    let w = Math.round(cssW * effectiveDpr);
    let h = Math.round(cssH * effectiveDpr);
    if (this.forcedRenderWidth > 0 && this.forcedRenderHeight > 0) {
      w = this.forcedRenderWidth;
      h = this.forcedRenderHeight;
    }

    const nextDprX = w / cssW;
    const nextDprY = h / cssH;
    const dprX = Number.isFinite(nextDprX) && nextDprX > 0 ? nextDprX : deviceDpr;
    const dprY = Number.isFinite(nextDprY) && nextDprY > 0 ? nextDprY : deviceDpr;
    const dpr = (dprX + dprY) * 0.5;

    if (applyImmediately) {
      this.applyCanvasSize(w, h, dprX, dprY, dpr);
      return;
    }

    this.pendingCanvasWidth = w;
    this.pendingCanvasHeight = h;
    this.pendingDprX = dprX;
    this.pendingDprY = dprY;
    this.pendingDpr = dpr;

    if (
      this.canvas.width !== w
      || this.canvas.height !== h
      || Math.abs(this.dprX - dprX) > 0.0001
      || Math.abs(this.dprY - dprY) > 0.0001
    ) {
      this.dirty = true;
    }

    this.syncPresentCanvasPosition();
  }

  private applyCanvasSize(
    width: number,
    height: number,
    dprX: number,
    dprY: number,
    dpr: number,
  ): void {
    this.dprX = dprX;
    this.dprY = dprY;
    this.dpr = dpr;
    this.presentCssWidth = Math.max(1, width / dprX);
    this.presentCssHeight = Math.max(1, height / dprY);

    if (this.canvas.width !== width || this.canvas.height !== height) {
      this.canvas.width = width;
      this.canvas.height = height;
    }

    const cpuSurface = this.getCpuSurfaceCanvas();
    if (cpuSurface.width !== width || cpuSurface.height !== height) {
      cpuSurface.width = width;
      cpuSurface.height = height;
      this.invalidateRenderCache();
      this.dirty = true;
    }

    if (this.gpuCanvas) {
      if (this.gpuCanvas.width !== width || this.gpuCanvas.height !== height) {
        this.gpuCanvas.width = width;
        this.gpuCanvas.height = height;
        this.wasm.gpu_resize_surface(width, height);
        this.dirty = true;
      }
    }
    this.syncPresentCanvasPosition();
  }

  private commitPendingSize(): void {
    if (this.pendingCanvasWidth <= 0 || this.pendingCanvasHeight <= 0) {
      return;
    }

    const width = this.pendingCanvasWidth;
    const height = this.pendingCanvasHeight;
    const dprX = this.pendingDprX > 0 ? this.pendingDprX : this.dprX;
    const dprY = this.pendingDprY > 0 ? this.pendingDprY : this.dprY;
    const dpr = this.pendingDpr > 0 ? this.pendingDpr : (dprX + dprY) * 0.5;

    this.pendingCanvasWidth = 0;
    this.pendingCanvasHeight = 0;
    this.pendingDprX = 0;
    this.pendingDprY = 0;
    this.pendingDpr = 0;

    this.applyCanvasSize(width, height, dprX, dprY, dpr);
  }

  private matchOverlayCanvasPosition(
    overlayCanvas: HTMLCanvasElement,
    cssWidth: number,
    cssHeight: number,
  ): void {
    // Position the GPU overlay exactly over the canvas content box
    // (inside border/padding) so it matches the CPU drawable area.
    const rect = this.canvas.getBoundingClientRect();
    const parentRect = this.canvas.parentElement?.getBoundingClientRect();
    const bw = this.canvas.clientLeft;  // border-left width
    const bt = this.canvas.clientTop;   // border-top width
    if (parentRect) {
      overlayCanvas.style.top = `${rect.top - parentRect.top + bt}px`;
      overlayCanvas.style.left = `${rect.left - parentRect.left + bw}px`;
    }
    overlayCanvas.style.width = `${Math.max(1, cssWidth)}px`;
    overlayCanvas.style.height = `${Math.max(1, cssHeight)}px`;
  }

  private syncPresentCanvasPosition(): void {
    const cssWidth = this.presentCssWidth > 0
      ? this.presentCssWidth
      : Math.max(1, this.canvas.clientWidth);
    const cssHeight = this.presentCssHeight > 0
      ? this.presentCssHeight
      : Math.max(1, this.canvas.clientHeight);
    if (this.cpuCanvas) {
      this.matchOverlayCanvasPosition(this.cpuCanvas, cssWidth, cssHeight);
    }
    if (this.gpuCanvas) {
      this.matchOverlayCanvasPosition(this.gpuCanvas, cssWidth, cssHeight);
    }
  }

  private invalidateRenderCache(): void {
    this.renderMemoryBuffer = null;
    this.renderPixelView = null;
    this.renderImageData = null;
    this.renderPtr = 0;
    this.renderByteLength = 0;
    this.renderWidth = 0;
    this.renderHeight = 0;
  }

  private getRenderImageData(
    ptr: number,
    len: number,
    width: number,
    height: number,
  ): ImageData | null {
    const required = width * height * 4;
    if (ptr <= 0 || len < required) {
      return null;
    }

    const wasmMemory: WebAssembly.Memory = this.wasm.wasm_memory();
    const memoryBuffer = wasmMemory.buffer;
    const cacheInvalid =
      this.renderPixelView == null ||
      this.renderImageData == null ||
      this.renderMemoryBuffer !== memoryBuffer ||
      this.renderPtr !== ptr ||
      this.renderByteLength !== required ||
      this.renderWidth !== width ||
      this.renderHeight !== height;

    if (cacheInvalid) {
      this.renderPixelView = new Uint8ClampedArray(memoryBuffer as ArrayBuffer, ptr, required);
      this.renderImageData = new ImageData(
        this.renderPixelView as unknown as Uint8ClampedArray<ArrayBuffer>,
        width,
        height,
      );
      this.renderMemoryBuffer = memoryBuffer;
      this.renderPtr = ptr;
      this.renderByteLength = required;
      this.renderWidth = width;
      this.renderHeight = height;
    }

    return this.renderImageData;
  }

  private getDirtyRect(
    width: number,
    height: number,
  ): { x: number; y: number; w: number; h: number } | null {
    const dirtyXFn = this.wasm.render_dirty_x;
    const dirtyYFn = this.wasm.render_dirty_y;
    const dirtyWFn = this.wasm.render_dirty_w;
    const dirtyHFn = this.wasm.render_dirty_h;
    if (typeof dirtyXFn !== "function"
      || typeof dirtyYFn !== "function"
      || typeof dirtyWFn !== "function"
      || typeof dirtyHFn !== "function") {
      return null;
    }

    const rawX = Number(dirtyXFn());
    const rawY = Number(dirtyYFn());
    const rawW = Number(dirtyWFn());
    const rawH = Number(dirtyHFn());
    if (!Number.isFinite(rawX)
      || !Number.isFinite(rawY)
      || !Number.isFinite(rawW)
      || !Number.isFinite(rawH)) {
      return null;
    }

    const x = Math.max(0, Math.min(width, Math.trunc(rawX)));
    const y = Math.max(0, Math.min(height, Math.trunc(rawY)));
    const w = Math.max(0, Math.min(width - x, Math.trunc(rawW)));
    const h = Math.max(0, Math.min(height - y, Math.trunc(rawH)));
    if (w <= 0 || h <= 0) {
      return null;
    }
    return { x, y, w, h };
  }

  private render(): void {
    this.commitPendingSize();
    const cpuSurface = this.getCpuSurfaceCanvas();
    const w = cpuSurface.width;
    const h = cpuSurface.height;
    if (w <= 0 || h <= 0) return;

    // ── GPU path (renders to separate gpuCanvas) ─────────────────────
    if (this.useGpu && this.gpuCanvas) {
      this.gpuCanvas.style.display = "block";
      this.wasm.render_gpu(this.gridId, this.gpuCanvas.width, this.gpuCanvas.height);
      return;
    }

    // CPU mode — hide GPU overlay so the 2D canvas is visible
    if (this.gpuCanvas) {
      this.gpuCanvas.style.display = "none";
    }

    // ── CPU path ──────────────────────────────────────────────────────
    const streamRender = this.renderViaRenderSession(w, h);
    const painted = streamRender
      ? (streamRender.painted ? 1 : 0)
      : this.wasm.render(this.gridId, w, h);

    if (painted) {
      const ptr = Number(this.wasm.render_buffer_ptr());
      const len = Number(this.wasm.render_buffer_len());
      const imageData = this.getRenderImageData(ptr, len, w, h);
      if (!imageData) {
        return;
      }

      const ctx = this.ensureCtx();
      const dirtyRect = streamRender?.dirtyRect ?? this.getDirtyRect(w, h);
      if (dirtyRect) {
        ctx.putImageData(
          imageData,
          0,
          0,
          dirtyRect.x,
          dirtyRect.y,
          dirtyRect.w,
          dirtyRect.h,
        );
      } else {
        ctx.putImageData(imageData, 0, 0);
      }
    }
  }

  private renderViaRenderSession(
    width: number,
    height: number,
  ): { painted: boolean; dirtyRect: { x: number; y: number; w: number; h: number } | null } | null {
    if (typeof this.wasm.volvox_grid_stream_open !== "function"
      || typeof this.wasm.volvox_grid_stream_send !== "function"
      || typeof this.wasm.volvox_grid_stream_recv !== "function"
      || typeof this.wasm.volvox_grid_stream_close_send !== "function"
      || typeof this.wasm.volvox_grid_stream_close !== "function") {
      return null;
    }

    const handle = this.wasm.volvox_grid_stream_open(
      "/volvoxgrid.v1.VolvoxGridService/RenderSession",
    ) as unknown;
    if (!isValidStreamHandle(handle)) {
      return null;
    }

    try {
      const request = pbEncodeRenderBufferInput(this.gridId, width, height);
      const sendStatus = Number(this.wasm.volvox_grid_stream_send(handle, request));
      if (sendStatus !== 0) {
        return null;
      }
      this.wasm.volvox_grid_stream_close_send(handle);

      let painted = false;
      let dirtyRect: { x: number; y: number; w: number; h: number } | null = null;

      for (let i = 0; i < 64; i += 1) {
        const frame = this.wasm.volvox_grid_stream_recv(handle) as Uint8Array;
        if (!(frame instanceof Uint8Array) || frame.length < 1) {
          break;
        }
        const status = decodeSignedStatus(Number(frame[0]));
        if (status === STREAM_STATUS_DATA) {
          const decoded = pbDecodeRenderOutput(frame.slice(1));
          if (decoded.rendered) {
            painted = true;
          }
          if (decoded.dirtyRect) {
            dirtyRect = decoded.dirtyRect;
          }
          continue;
        }
        if (status < 0) {
          throwFfiErrorPayload(frame.slice(1));
        }
        if (status === STREAM_STATUS_EOF || status === STREAM_STATUS_PENDING) {
          break;
        }
        break;
      }

      return { painted, dirtyRect };
    } finally {
      this.wasm.volvox_grid_stream_close(handle);
    }
  }

  private startRenderLoop(): void {
    const frame = (ts: number) => {
      if (this.destroyed) return;

      const dtMs = this.lastFrameTs > 0 ? Math.min(50, ts - this.lastFrameTs) : 16;
      this.lastFrameTs = ts;
      this.wasm.tick_fling(this.gridId, dtMs);
      if (typeof this.wasm.resolve_expired_event_decisions === "function") {
        this.wasm.resolve_expired_event_decisions(this.gridId);
      }
      if (this.hasCancelableEventListeners()) {
        this.flushCancelableEventDecisions();
      }

      if (this.dirty || this.wasm.is_dirty(this.gridId)) {
        this.render();
        this.dirty = false;
      }

      this.syncHostEditor();

      this.animFrame = requestAnimationFrame(frame);
    };
    this.animFrame = requestAnimationFrame(frame);
  }

  private resetTouchState(): void {
    this.touchPoints.clear();
    this.touchMode = "none";
    this.activeTouchPointerId = null;
    this.touchPanActive = false;
    this.pinchLastDistance = 0;
    this.pinchLastCenterX = 0;
    this.pinchLastCenterY = 0;
  }

  private ensureZoomBaseForGrid(gridId: number): void {
    if (!this.zoomScaleByGrid.has(gridId)) {
      this.zoomScaleByGrid.set(gridId, 1.0);
    }
    if (!this.zoomBaseFontSizeByGrid.has(gridId)) {
      const fallback = 14.0 * this.dpr;
      const raw = typeof this.wasm.get_font_size === "function"
        ? Number(this.wasm.get_font_size(gridId))
        : fallback;
      const base = Number.isFinite(raw) && raw > 0 ? raw : fallback;
      this.zoomBaseFontSizeByGrid.set(gridId, base);
    }
    if (!this.zoomBaseRowHeightByGrid.has(gridId)) {
      const fallback = 20;
      const raw = typeof this.wasm.get_default_row_height === "function"
        ? Number(this.wasm.get_default_row_height(gridId))
        : fallback;
      const base = Number.isFinite(raw) && raw > 0 ? Math.round(raw) : fallback;
      this.zoomBaseRowHeightByGrid.set(gridId, base);
    }
    if (!this.zoomBaseColWidthByGrid.has(gridId)) {
      const fallback = 70;
      const raw = typeof this.wasm.get_default_col_width === "function"
        ? Number(this.wasm.get_default_col_width(gridId))
        : fallback;
      const base = Number.isFinite(raw) && raw > 0 ? Math.round(raw) : fallback;
      this.zoomBaseColWidthByGrid.set(gridId, base);
    }
  }

  private refreshZoomBaseForGrid(gridId: number): void {
    const fallbackFont = 14.0 * this.dpr;
    const rawFont = typeof this.wasm.get_font_size === "function"
      ? Number(this.wasm.get_font_size(gridId))
      : fallbackFont;
    const nextFont = Number.isFinite(rawFont) && rawFont > 0 ? rawFont : fallbackFont;
    this.zoomBaseFontSizeByGrid.set(gridId, nextFont);

    const fallbackRow = 20;
    const rawRow = typeof this.wasm.get_default_row_height === "function"
      ? Number(this.wasm.get_default_row_height(gridId))
      : fallbackRow;
    const nextRow = Number.isFinite(rawRow) && rawRow > 0 ? Math.round(rawRow) : fallbackRow;
    this.zoomBaseRowHeightByGrid.set(gridId, nextRow);

    const fallbackCol = 70;
    const rawCol = typeof this.wasm.get_default_col_width === "function"
      ? Number(this.wasm.get_default_col_width(gridId))
      : fallbackCol;
    const nextCol = Number.isFinite(rawCol) && rawCol > 0 ? Math.round(rawCol) : fallbackCol;
    this.zoomBaseColWidthByGrid.set(gridId, nextCol);

    // Pinch gestures are relative to the live grid state at gesture start.
    this.zoomScaleByGrid.set(gridId, 1.0);
  }

  private applyZoomStep(stepScale: number): void {
    if (!Number.isFinite(stepScale) || stepScale <= 0) {
      return;
    }
    const normalized = Math.max(
      VolvoxGrid.ZOOM_STEP_MIN_SCALE,
      Math.min(VolvoxGrid.ZOOM_STEP_MAX_SCALE, stepScale),
    );
    if (Math.abs(normalized - 1.0) <= VolvoxGrid.ZOOM_STEP_NOISE_EPSILON) {
      return;
    }
    this.ensureZoomBaseForGrid(this.gridId);
    const current = this.zoomScaleByGrid.get(this.gridId) ?? 1.0;
    const target = Math.max(
      VolvoxGrid.ZOOM_MIN_SCALE,
      Math.min(VolvoxGrid.ZOOM_MAX_SCALE, current * normalized),
    );
    if (Math.abs(target - current) <= VolvoxGrid.ZOOM_STEP_NOISE_EPSILON) {
      return;
    }
    this.zoomScaleByGrid.set(this.gridId, target);
    this.applyZoomScaleToCurrentGrid(target, current);
  }

  private applyZoomScaleToCurrentGrid(scale: number, previousScale: number): void {
    this.ensureZoomBaseForGrid(this.gridId);
    const safeScale = Math.max(
      VolvoxGrid.ZOOM_MIN_SCALE,
      Math.min(VolvoxGrid.ZOOM_MAX_SCALE, scale),
    );
    const prevScale = Number.isFinite(previousScale) && previousScale > 0
      ? previousScale
      : safeScale;
    const baseFont = this.zoomBaseFontSizeByGrid.get(this.gridId) ?? 13.0;
    const baseRow = this.zoomBaseRowHeightByGrid.get(this.gridId) ?? 20;
    const baseCol = this.zoomBaseColWidthByGrid.get(this.gridId) ?? 70;

    if (typeof this.wasm.set_font_size === "function") {
      this.wasm.set_font_size(
        this.gridId,
        Math.max(8.0, Math.min(48.0, baseFont * safeScale)),
      );
    }

    const nextRow = Math.max(1, Math.round(baseRow * safeScale));
    if (typeof this.wasm.set_default_row_height === "function") {
      this.wasm.set_default_row_height(this.gridId, nextRow);
    } else {
      this.wasm.set_row_height(this.gridId, -1, nextRow);
    }
    const relativeRowScale = safeScale / prevScale;
    if (typeof this.wasm.scale_row_height_overrides === "function"
      && Number.isFinite(relativeRowScale)
      && relativeRowScale > 0
      && Math.abs(relativeRowScale - 1.0) > VolvoxGrid.ZOOM_STEP_NOISE_EPSILON) {
      this.wasm.scale_row_height_overrides(this.gridId, relativeRowScale);
    }

    const nextCol = Math.max(1, Math.round(baseCol * safeScale));
    if (typeof this.wasm.set_default_col_width === "function") {
      this.wasm.set_default_col_width(this.gridId, nextCol);
    } else {
      this.wasm.set_col_width(this.gridId, -1, nextCol);
    }
    const relativeColScale = safeScale / prevScale;
    if (typeof this.wasm.scale_col_width_overrides === "function"
      && Number.isFinite(relativeColScale)
      && relativeColScale > 0
      && Math.abs(relativeColScale - 1.0) > VolvoxGrid.ZOOM_STEP_NOISE_EPSILON) {
      this.wasm.scale_col_width_overrides(this.gridId, relativeColScale);
    }

    if (typeof this.wasm.set_debug_zoom_level === "function") {
      this.wasm.set_debug_zoom_level(this.gridId, safeScale);
    }

    this.dirty = true;
    if (this.onZoomChange) {
      this.onZoomChange(safeScale);
    }
  }

  private touchPinchMetrics():
    | { centerX: number; centerY: number; distance: number }
    | null {
    if (this.touchPoints.size < 2) {
      return null;
    }
    const points = [...this.touchPoints.values()];
    const p1 = points[0];
    const p2 = points[1];
    const centerX = (p1.x + p2.x) * 0.5;
    const centerY = (p1.y + p2.y) * 0.5;
    const distance = Math.hypot(p2.x - p1.x, p2.y - p1.y);
    return { centerX, centerY, distance };
  }

  private beginPinchGesture(): void {
    const metrics = this.touchPinchMetrics();
    if (!metrics) {
      return;
    }
    this.refreshZoomBaseForGrid(this.gridId);
    this.touchMode = "pinch";
    this.activeTouchPointerId = null;
    this.touchPanActive = false;
    this.pinchLastCenterX = metrics.centerX;
    this.pinchLastCenterY = metrics.centerY;
    this.pinchLastDistance = metrics.distance;
  }

  private updatePinchGesture(): void {
    const metrics = this.touchPinchMetrics();
    if (!metrics) {
      return;
    }

    const panDx = metrics.centerX - this.pinchLastCenterX;
    const panDy = metrics.centerY - this.pinchLastCenterY;
    if (panDx !== 0 || panDy !== 0) {
      this.wasm.handle_scroll(
        this.gridId,
        -panDx / VolvoxGrid.TOUCH_SCROLL_LINE_PX,
        -panDy / VolvoxGrid.TOUCH_SCROLL_LINE_PX,
      );
      this.dirty = true;
    }

    if (this.pinchLastDistance > 0 && metrics.distance > 0) {
      const stepScale = metrics.distance / this.pinchLastDistance;
      this.applyZoomStep(stepScale);
    }

    this.pinchLastCenterX = metrics.centerX;
    this.pinchLastCenterY = metrics.centerY;
    this.pinchLastDistance = metrics.distance;
  }

  // ── Internal: event wiring ───────────────────────────────────────────

  private onPointerDown = (e: PointerEvent): void => {
    const r = this.canvas.getBoundingClientRect();
    const x = e.clientX - r.left;
    const y = e.clientY - r.top;
    if (e.pointerType === "touch") {
      this.touchPoints.set(e.pointerId, { x, y });
      this.canvas.setPointerCapture(e.pointerId);
      this.canvas.focus();
      e.preventDefault();

      if (this.touchPoints.size >= 2) {
        this.beginPinchGesture();
        return;
      }

      // Forward touch to engine so it can hit-test FastScroll.
      const ex = x * this.dprX;
      const ey = y * this.dprY;
      this.wasm.handle_pointer_down(this.gridId, ex, ey, 0, 0, false);
      this.flushCancelableEventDecisions();
      if (typeof this.wasm.is_fast_scroll_active === "function" &&
          this.wasm.is_fast_scroll_active(this.gridId)) {
        this.touchMode = "fast-scroll";
        this.activeTouchPointerId = e.pointerId;
        this.dirty = true;
        return;
      }

      this.touchMode = "pan";
      this.activeTouchPointerId = e.pointerId;
      this.touchStartX = x;
      this.touchStartY = y;
      this.touchLastX = x;
      this.touchLastY = y;
      this.touchPanActive = false;
      return;
    }

    // Scale CSS coordinates to device pixels for the engine.
    const ex = x * this.dprX;
    const ey = y * this.dprY;

    const button = e.button;
    const modifier = this.modifierBits(e);
    const wasEditing = this.wasm.is_editing(this.gridId) !== 0;

    // Engine-rendered combo dropdown path (non-editable combos).
    if (wasEditing && this.activeEditor === "none") {
      const idx =
        typeof this.wasm.dropdown_hit_index === "function"
          ? Number(this.wasm.dropdown_hit_index(this.gridId, ex, ey))
          : Number(this.wasm.combo_dropdown_hit_index(this.gridId, ex, ey));
      if (idx >= 0) {
        if (typeof this.wasm.choose_dropdown_item === "function") {
          this.wasm.choose_dropdown_item(this.gridId, idx);
        } else {
          this.wasm.choose_combo_dropdown_item(this.gridId, idx);
        }
        this.flushCancelableEventDecisions();
        this.dirty = true;
        this.canvas.focus();
        return;
      }
      // Click outside dropdown: cancel previewed combo selection and close.
      this.wasm.cancel_edit(this.gridId);
      this.flushCancelableEventDecisions();
      this.dirty = true;
    }

    // Re-check editing state after possible commit above.
    const editingBeforeDown = this.wasm.is_editing(this.gridId) !== 0;

    // Right-click (button 2): update mouse tracking for hit-test but do NOT
    // change selection — this preserves multi-select / row-select / col-select
    // so the context menu operates on the existing selection.
    if (button === 2) {
      this.wasm.handle_pointer_move(this.gridId, ex, ey);
      this.canvas.focus();
      return;
    }

    // detail >= 2 means double-click
    const dblClick = (e as any).detail >= 2;
    this.wasm.handle_pointer_down(this.gridId, ex, ey, button, modifier, dblClick);
    this.flushCancelableEventDecisions();

    // Single click on combo cells opens edit dropdown like desktop hosts.
    const nowEditing = this.wasm.is_editing(this.gridId) !== 0;
    if (!editingBeforeDown && !nowEditing && button === 0 && modifier === 0) {
      const row = Number(this.wasm.get_selection_row(this.gridId));
      const col = Number(this.wasm.get_selection_col(this.gridId));
      const fixedRows = Number(this.wasm.get_fixed_rows(this.gridId));
      const fixedCols = Number(this.wasm.get_fixed_cols(this.gridId));
      if (row >= fixedRows && col >= fixedCols) {
        const list =
          typeof this.wasm.get_active_dropdown_list === "function"
            ? String(this.wasm.get_active_dropdown_list(this.gridId, row, col) || "")
            : String(this.wasm.get_active_combo_list(this.gridId, row, col) || "");
        if (list.length > 0 && list.trim() !== "...") {
          this.wasm.begin_edit_at_selection(this.gridId);
          this.flushCancelableEventDecisions();
        }
      }
    }

    this.dirty = true;
    this.canvas.setPointerCapture(e.pointerId);
    this.canvas.focus();
  };

  private onPointerMove = (e: PointerEvent): void => {
    const r = this.canvas.getBoundingClientRect();
    const x = e.clientX - r.left;
    const y = e.clientY - r.top;

    if (e.pointerType === "touch") {
      if (this.touchPoints.has(e.pointerId)) {
        this.touchPoints.set(e.pointerId, { x, y });
      }

      if (this.touchMode === "fast-scroll" &&
          this.activeTouchPointerId !== null &&
          e.pointerId === this.activeTouchPointerId) {
        const ex = x * this.dprX;
        const ey = y * this.dprY;
        this.wasm.handle_pointer_move(this.gridId, ex, ey);
        this.dirty = true;
        e.preventDefault();
        return;
      }

      if (this.touchMode === "pinch") {
        if (this.touchPoints.size >= 2) {
          this.updatePinchGesture();
          e.preventDefault();
          return;
        }
        if (this.touchPoints.size === 1) {
          const [id, pt] = [...this.touchPoints.entries()][0];
          this.touchMode = "pan";
          this.activeTouchPointerId = id;
          this.touchStartX = pt.x;
          this.touchStartY = pt.y;
          this.touchLastX = pt.x;
          this.touchLastY = pt.y;
          this.touchPanActive = false;
        } else {
          this.touchMode = "none";
        }
      }

      if (
        this.touchMode === "pan" &&
        this.activeTouchPointerId !== null &&
        e.pointerId === this.activeTouchPointerId
      ) {
        // Touch tracking stays in CSS pixels for scroll unit computation.
        const dxPx = x - this.touchLastX;
        const dyPx = y - this.touchLastY;
        this.touchLastX = x;
        this.touchLastY = y;

        if (!this.touchPanActive) {
          const travelX = x - this.touchStartX;
          const travelY = y - this.touchStartY;
          if (Math.hypot(travelX, travelY) >= VolvoxGrid.TOUCH_PAN_START_PX) {
            this.touchPanActive = true;
          }
        }

        if (this.touchPanActive) {
          // Finger drag direction is inverse of content scroll direction.
          const unitsX = -dxPx / VolvoxGrid.TOUCH_SCROLL_LINE_PX;
          const unitsY = -dyPx / VolvoxGrid.TOUCH_SCROLL_LINE_PX;
          this.wasm.handle_scroll(this.gridId, unitsX, unitsY);
          this.dirty = true;
        }
        e.preventDefault();
        return;
      }

      if (this.touchMode !== "none") {
        e.preventDefault();
      }
      return;
    }

    const button = e.buttons;
    const modifier = this.modifierBits(e);
    this.wasm.handle_pointer_move(this.gridId, x * this.dprX, y * this.dprY, button, modifier);

    // Sync cursor style from engine
    const cursorStyle = Number(this.wasm.get_cursor_style(this.gridId));
    const CURSOR_MAP = ["default", "col-resize", "row-resize", "grab"];
    this.canvas.style.cursor = CURSOR_MAP[cursorStyle] ?? "default";

    if (e.buttons) {
      this.dirty = true;
    }
  };

  private onPointerUp = (e: PointerEvent): void => {
    const r = this.canvas.getBoundingClientRect();
    const x = e.clientX - r.left;
    const y = e.clientY - r.top;
    const ex = x * this.dprX;
    const ey = y * this.dprY;

    if (e.pointerType === "touch") {
      const wasFastScroll = this.touchMode === "fast-scroll" &&
        this.activeTouchPointerId !== null &&
        e.pointerId === this.activeTouchPointerId;
      if (wasFastScroll) {
        this.wasm.handle_pointer_up(this.gridId, ex, ey, 0);
        this.touchMode = "none";
        this.activeTouchPointerId = null;
        this.dirty = true;
      }

      const wasPan = this.touchMode === "pan";
      const wasActivePanPointer =
        this.activeTouchPointerId !== null && e.pointerId === this.activeTouchPointerId;
      if (wasPan && wasActivePanPointer) {
        // pointer_down was sent on touch start; send matching pointer_up.
        this.wasm.handle_pointer_up(this.gridId, ex, ey, 0);
      }

      this.touchPoints.delete(e.pointerId);

      if (this.touchPoints.size >= 2) {
        this.beginPinchGesture();
      } else if (this.touchPoints.size === 1) {
        const [id, pt] = [...this.touchPoints.entries()][0];
        this.touchMode = "pan";
        this.activeTouchPointerId = id;
        this.touchStartX = pt.x;
        this.touchStartY = pt.y;
        this.touchLastX = pt.x;
        this.touchLastY = pt.y;
        this.touchPanActive = false;
      } else {
        this.resetTouchState();
      }

      this.dirty = true;
      try {
        this.canvas.releasePointerCapture(e.pointerId);
      } catch {
        // Ignore invalid capture state.
      }
      e.preventDefault();
      return;
    }

    this.wasm.handle_pointer_up(this.gridId, ex, ey, e.button);
    this.dirty = true;
    this.canvas.releasePointerCapture(e.pointerId);
  };

  private onPointerCancel = (e: PointerEvent): void => {
    if (e.pointerType === "touch") {
      if (this.touchMode === "fast-scroll" &&
          this.activeTouchPointerId !== null &&
          e.pointerId === this.activeTouchPointerId) {
        const r = this.canvas.getBoundingClientRect();
        const ex = (e.clientX - r.left) * this.dprX;
        const ey = (e.clientY - r.top) * this.dprY;
        this.wasm.handle_pointer_up(this.gridId, ex, ey, 0);
        this.touchMode = "none";
        this.activeTouchPointerId = null;
        this.dirty = true;
      }
      this.touchPoints.delete(e.pointerId);
      if (this.touchPoints.size >= 2) {
        this.beginPinchGesture();
      } else if (this.touchPoints.size === 1) {
        const [id, pt] = [...this.touchPoints.entries()][0];
        this.touchMode = "pan";
        this.activeTouchPointerId = id;
        this.touchStartX = pt.x;
        this.touchStartY = pt.y;
        this.touchLastX = pt.x;
        this.touchLastY = pt.y;
        this.touchPanActive = false;
      } else {
        this.resetTouchState();
      }
    }
    try {
      this.canvas.releasePointerCapture(e.pointerId);
    } catch {
      // Ignore invalid capture state.
    }
  };

  private onWheel = (e: WheelEvent): void => {
    e.preventDefault();
    const dx = e.deltaX / 100;
    const dy = e.deltaY / 100;
    this.wasm.handle_scroll(this.gridId, dx, dy);
    this.dirty = true;
  };

  private setupEventListeners(): void {
    const c = this.canvas;
    c.style.touchAction = "none";
    c.addEventListener("pointerdown", this.onPointerDown);
    c.addEventListener("pointermove", this.onPointerMove);
    c.addEventListener("pointerup", this.onPointerUp);
    c.addEventListener("pointercancel", this.onPointerCancel);
    c.addEventListener("wheel", this.onWheel, { passive: false });

    // Make the canvas focusable so it receives keyboard events
    if (!c.hasAttribute("tabindex")) {
      c.setAttribute("tabindex", "0");
    }
  }

  private removeEventListeners(): void {
    const c = this.canvas;
    c.removeEventListener("pointerdown", this.onPointerDown);
    c.removeEventListener("pointermove", this.onPointerMove);
    c.removeEventListener("pointerup", this.onPointerUp);
    c.removeEventListener("pointercancel", this.onPointerCancel);
    c.removeEventListener("wheel", this.onWheel);
  }

  private modifierBits(e: PointerEvent | KeyboardEvent): number {
    let m = 0;
    if (e.shiftKey) m |= 1;
    if (e.ctrlKey || e.metaKey) m |= 2;
    if (e.altKey) m |= 4;
    return m;
  }


  private initHostEditors(): void {
    const commonStyle = (el: HTMLElement) => {
      el.style.position = "fixed";
      el.style.display = "none";
      el.style.zIndex = "2147483000";
      el.style.boxSizing = "border-box";
      el.style.border = "1px solid #2a6fd4";
      el.style.outline = "none";
      el.style.margin = "0";
      el.style.padding = "0 4px";
      el.style.font = "14px \"Noto Sans KR\", \"Noto Sans\", \"Segoe UI\", sans-serif";
      el.style.background = "#ffffff";
      el.style.color = "#111111";
    };

    this.editInput.type = "text";
    this.editInput.autocomplete = "off";
    this.editInput.autocapitalize = "off";
    this.editInput.spellcheck = false;
    this.editInput.setAttribute("data-volvoxgrid-editor", "text");
    commonStyle(this.editInput);

    this.editSelect.setAttribute("data-volvoxgrid-editor", "combo");
    commonStyle(this.editSelect);
    this.editSelect.style.padding = "0";

    this.editDataList.id = this.editDataListId;
    this.editDataList.setAttribute("data-volvoxgrid-editor", "datalist");

    document.body.appendChild(this.editInput);
    document.body.appendChild(this.editSelect);
    document.body.appendChild(this.editDataList);

    this.editInput.addEventListener("compositionstart", () => {
      this.editComposing = true;
    });
    this.editInput.addEventListener("compositionend", () => {
      this.editComposing = false;
      this.pushInputValueToEngine();
    });
    this.editInput.addEventListener("input", () => {
      if (this.suppressEditorInput) return;
      this.pushInputValueToEngine();
    });
    this.editInput.addEventListener("keydown", (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        this.cancelEditFromHost();
        return;
      }
      if (e.key === "Tab") {
        e.preventDefault();
        this.commitEditFromHost(true, this.modifierBits(e));
        return;
      }
      if (e.key === "Enter" && !(e as any).isComposing) {
        e.preventDefault();
        this.commitEditFromHost(false, 0);
      }
    });
    this.editInput.addEventListener("blur", () => {
      if (this.suppressBlurCommit) return;
      if (this.activeEditor === "text" || this.activeEditor === "combo-input") {
        this.commitEditFromHost(false, 0);
      }
    });

    this.editSelect.addEventListener("change", () => {
      if (!this.wasm.is_editing(this.gridId)) return;
      const idx = this.editSelect.selectedIndex;
      if (idx >= 0) {
        this.wasm.set_edit_dropdown_index(this.gridId, idx);
      }
      this.commitEditFromHost(false, 0);
    });
    this.editSelect.addEventListener("keydown", (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        this.cancelEditFromHost();
        return;
      }
      if (e.key === "Tab") {
        e.preventDefault();
        this.commitEditFromHost(true, this.modifierBits(e));
        return;
      }
      if (e.key === "Enter") {
        e.preventDefault();
        this.commitEditFromHost(false, 0);
      }
    });
    this.editSelect.addEventListener("blur", () => {
      if (this.suppressBlurCommit) return;
      if (this.activeEditor === "combo-select") {
        this.commitEditFromHost(false, 0);
      }
    });
  }

  private removeHostEditors(): void {
    this.hideHostEditors(false);
    this.editInput.remove();
    this.editSelect.remove();
    this.editDataList.remove();
  }

  private syncHostEditor(): void {
    if (this.destroyed) return;
    const editing = this.wasm.is_editing(this.gridId) !== 0;
    if (!editing) {
      this.hideHostEditors(false);
      return;
    }

    const row = Number(this.wasm.get_edit_row(this.gridId));
    const col = Number(this.wasm.get_edit_col(this.gridId));
    const x = Number(this.wasm.get_edit_cell_x(this.gridId));
    const y = Number(this.wasm.get_edit_cell_y(this.gridId));
    const w = Number(this.wasm.get_edit_cell_w(this.gridId));
    const h = Number(this.wasm.get_edit_cell_h(this.gridId));
    if (x < 0 || y < 0 || w <= 0 || h <= 0) {
      this.hideHostEditors(false);
      return;
    }

    const rect = this.canvas.getBoundingClientRect();
    // Engine returns positions in device pixels; convert to CSS for DOM layout.
    const left = rect.left + x / this.dprX;
    const top = rect.top + y / this.dprY;
    const width = Math.max(8, w / this.dprX);
    const height = Math.max(8, h / this.dprY);
    const cellKey = `${row}:${col}`;

    const comboCount = Number(this.wasm.get_edit_dropdown_count(this.gridId));
    if (comboCount > 0) {
      const comboEditable = this.wasm.is_edit_dropdown_editable(this.gridId) !== 0;
      if (comboEditable) {
        // Editable combo: show host <input> with datalist for typing + autocomplete
        const items = this.readComboItems(comboCount);
        const text = String(this.wasm.get_edit_text(this.gridId) || "");
        this.syncInputEditor("combo-input", cellKey, left, top, width, height, text, items);
      } else {
        // Non-editable combo: engine renders the dropdown directly.
        // No host editor needed — just hide any stale host editor.
        this.hideHostEditors(false);
      }
      return;
    }

    const text = String(this.wasm.get_edit_text(this.gridId) || "");
    this.syncInputEditor("text", cellKey, left, top, width, height, text, null);
  }

  private syncInputEditor(
    kind: "text" | "combo-input",
    cellKey: string,
    left: number,
    top: number,
    width: number,
    height: number,
    text: string,
    comboItems: string[] | null,
  ): void {
    if (this.activeEditor !== kind || this.editorCellKey !== cellKey) {
      if (comboItems) {
        this.populateDataList(comboItems);
        this.editInput.setAttribute("list", this.editDataListId);
      } else {
        this.editInput.removeAttribute("list");
        this.editDataList.replaceChildren();
      }
      this.suppressEditorInput = true;
      this.editInput.value = text;
      if (!this.suppressEditorSelect) {
        this.editInput.select();
      }
      this.suppressEditorInput = false;
      this.showInputEditor(kind, cellKey, left, top, width, height);
      return;
    }

    this.positionEditor(this.editInput, left, top, width, height);
    this.editInput.style.display = "block";
    this.editSelect.style.display = "none";
    if (!this.editComposing && document.activeElement !== this.editInput) {
      if (this.editInput.value !== text) {
        this.suppressEditorInput = true;
        this.editInput.value = text;
        this.suppressEditorInput = false;
      }
    }
  }

  private syncSelectEditor(
    cellKey: string,
    left: number,
    top: number,
    width: number,
    height: number,
    items: string[],
    text: string,
    idx: number,
  ): void {
    if (this.activeEditor !== "combo-select" || this.editorCellKey !== cellKey) {
      this.populateSelect(items);
      this.showSelectEditor(cellKey, left, top, width, height);
    } else {
      this.positionEditor(this.editSelect, left, top, width, height);
      this.editSelect.style.display = "block";
      this.editInput.style.display = "none";
    }

    if (idx >= 0 && idx < this.editSelect.options.length) {
      if (this.editSelect.selectedIndex !== idx) {
        this.editSelect.selectedIndex = idx;
      }
    } else {
      let match = -1;
      for (let i = 0; i < this.editSelect.options.length; i++) {
        if (this.editSelect.options[i].value === text) {
          match = i;
          break;
        }
      }
      this.editSelect.selectedIndex = match;
    }
  }

  private showInputEditor(
    kind: "text" | "combo-input",
    cellKey: string,
    left: number,
    top: number,
    width: number,
    height: number,
  ): void {
    this.positionEditor(this.editInput, left, top, width, height);
    this.editInput.style.display = "block";
    this.editSelect.style.display = "none";
    this.activeEditor = kind;
    this.editorCellKey = cellKey;
    this.editInput.focus();
    if (!this.suppressEditorSelect) {
      this.editInput.select();
    }
  }

  private showSelectEditor(
    cellKey: string,
    left: number,
    top: number,
    width: number,
    height: number,
  ): void {
    this.positionEditor(this.editSelect, left, top, width, height);
    this.editSelect.style.display = "block";
    this.editInput.style.display = "none";
    this.activeEditor = "combo-select";
    this.editorCellKey = cellKey;
    this.editSelect.focus();
  }

  private hideHostEditors(focusCanvas: boolean): void {
    if (this.activeEditor === "none"
      && this.editInput.style.display === "none"
      && this.editSelect.style.display === "none") {
      if (focusCanvas) this.canvas.focus();
      return;
    }

    this.suppressBlurCommit = true;
    this.editInput.style.display = "none";
    this.editSelect.style.display = "none";
    if (document.activeElement === this.editInput) {
      this.editInput.blur();
    }
    if (document.activeElement === this.editSelect) {
      this.editSelect.blur();
    }
    this.suppressBlurCommit = false;
    this.activeEditor = "none";
    this.editorCellKey = "";
    if (focusCanvas) {
      this.canvas.focus();
    }
  }

  private commitEditFromHost(moveWithTab: boolean, tabModifier: number): void {
    let canceled = false;
    if (this.wasm.is_editing(this.gridId)) {
      if (this.activeEditor === "combo-select") {
        const idx = this.editSelect.selectedIndex;
        if (idx >= 0) {
          this.wasm.set_edit_dropdown_index(this.gridId, idx);
        }
      } else {
        this.pushInputValueToEngine();
      }
      this.wasm.commit_edit(this.gridId);
      canceled = this.flushCancelableEventDecisions();
    }

    if (moveWithTab && !canceled && this.wasm.is_editing(this.gridId) === 0) {
      this.wasm.handle_key_down(this.gridId, 9, tabModifier);
      this.flushCancelableEventDecisions();
    }
    if (this.wasm.is_editing(this.gridId)) {
      this.syncHostEditor();
      this.dirty = true;
      return;
    }
    this.hideHostEditors(true);
    this.dirty = true;
  }

  private cancelEditFromHost(): void {
    if (this.wasm.is_editing(this.gridId)) {
      this.wasm.cancel_edit(this.gridId);
    }
    this.hideHostEditors(true);
    this.dirty = true;
  }

  private pushInputValueToEngine(): void {
    if (!this.wasm.is_editing(this.gridId)) return;
    const value = this.editInput.value;
    this.wasm.set_edit_text(this.gridId, value);

    const startUnits = this.editInput.selectionStart ?? value.length;
    const endUnits = this.editInput.selectionEnd ?? startUnits;
    const a = Array.from(value.slice(0, startUnits)).length;
    const b = Array.from(value.slice(0, endUnits)).length;
    this.wasm.set_edit_selection(this.gridId, a, Math.max(0, b - a));
    this.dirty = true;
  }

  private readComboItems(count: number): string[] {
    const items: string[] = [];
    for (let i = 0; i < count; i++) {
      if (typeof this.wasm.get_edit_dropdown_item === "function") {
        items.push(String(this.wasm.get_edit_dropdown_item(this.gridId, i) || ""));
      } else {
        items.push(String(this.wasm.get_edit_combo_item(this.gridId, i) || ""));
      }
    }
    return items;
  }

  private populateDataList(items: string[]): void {
    this.editDataList.replaceChildren();
    for (const value of items) {
      const opt = document.createElement("option");
      opt.value = value;
      this.editDataList.appendChild(opt);
    }
  }

  private populateSelect(items: string[]): void {
    this.editSelect.replaceChildren();
    for (const value of items) {
      const opt = document.createElement("option");
      opt.value = value;
      opt.textContent = value;
      this.editSelect.appendChild(opt);
    }
  }

  private positionEditor(
    el: HTMLElement,
    left: number,
    top: number,
    width: number,
    height: number,
  ): void {
    el.style.left = `${Math.round(left)}px`;
    el.style.top = `${Math.round(top)}px`;
    el.style.width = `${Math.round(width)}px`;
    el.style.height = `${Math.round(height)}px`;
    el.style.lineHeight = `${Math.max(1, Math.round(height - 2))}px`;
  }

}
