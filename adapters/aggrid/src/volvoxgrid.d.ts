declare module "volvoxgrid" {
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

  export class VolvoxGrid {
    static readonly PIN_NONE: number;
    static readonly PIN_TOP: number;
    static readonly PIN_BOTTOM: number;
    static readonly PIN_COL_NONE: number;
    static readonly PIN_COL_LEFT: number;
    static readonly PIN_COL_RIGHT: number;
    static readonly STICKY_NONE: number;
    static readonly STICKY_TOP: number;
    static readonly STICKY_BOTTOM: number;
    static readonly STICKY_LEFT: number;
    static readonly STICKY_RIGHT: number;
    static readonly STICKY_BOTH: number;

    constructor(canvas: HTMLCanvasElement, wasm: unknown, rows?: number, cols?: number);

    get id(): number;
    get rowCount(): number;
    set rowCount(value: number);
    get colCount(): number;
    set colCount(value: number);
    frozenRowCount: number;
    frozenColCount: number;
    showColumnHeaders: boolean;
    showRowIndicator: boolean;
    columnIndicatorTopRowCount: number;

    get cursorRow(): number;
    set cursorRow(value: number);
    get cursorCol(): number;
    set cursorCol(value: number);
    onBeforeEdit: ((details: VolvoxGridBeforeEditDetails) => void) | null;
    onCellEditValidating: ((details: VolvoxGridCellEditValidatingDetails) => void) | null;
    onBeforeSort: ((details: VolvoxGridBeforeSortDetails) => void) | null;
    getSelection(): VolvoxGridSelection;
    selectRange(row1: number, col1: number, row2?: number, col2?: number, show?: boolean): void;
    selectRanges(ranges: ReadonlyArray<VolvoxGridCellRange>, activeRow?: number, activeCol?: number, show?: boolean): void;
    showCell(row: number, col: number): void;
    clearSelection(): void;
    topRow: number;
    leftCol: number;
    getBottomRow(): number;
    getRightCol(): number;

    destroy(): void;
    setCellText(row: number, col: number, text: string): void;
    getCellText(row: number, col: number): string;
    loadTable(rows: number, cols: number, values: unknown[]): void;
    clear(scope?: number, region?: number): void;

    setColWidth(col: number, width: number): void;
    setRowHeight(row: number, height: number): void;
    defaultColWidth: number;
    defaultRowHeight: number;
    setColumnCaption(col: number, caption: string): void;

    selectionMode: number;
    selectionVisibility: number;
    focusBorder: number;
    editTrigger: number;
    editable: boolean;
    dropdownTrigger: number;
    dropdownSearch: boolean;
    editMaxLength: number;
    editText: string;
    rendererMode: number;
    rendererBackend: number;
    presentMode: number;
    debugOverlay: boolean;
    animationEnabled: boolean;
    animationDurationMs: number;
    textLayoutCacheCap: number;
    cellSpanMode: number;
    scrollBars: number;
    mergeCells(r1: number, c1: number, r2: number, c2: number): void;
    unmergeCells(r1: number, c1: number, r2: number, c2: number): void;
    getMergedRegions(): { row1: number; col1: number; row2: number; col2: number }[];
    setFontName(name: string): void;
    setFontSize(size: number): void;
    setGridLines(mode: number): void;
    setHeaderFeatures(features: VolvoxGridHeaderFeatures): void;
    setResizePolicy(policy: VolvoxGridResizePolicy): void;
    setCellStyle(row: number, col: number, style: VolvoxGridCellStyle): void;
    setIconTheme(theme: VolvoxGridIconTheme): void;
    getIconTheme(): VolvoxGridIconTheme;
    setHeaderSeparator(style: VolvoxGridHeaderSeparator): void;
    setHeaderResizeHandle(style: VolvoxGridHeaderResizeHandle): void;
    setIconSlots(slots: VolvoxGridIconSlots): void;
    getIconSlots(): VolvoxGridIconSlots;
    setHeaderSeparatorStyle(style: VolvoxGridHeaderSeparatorStyle): void;
    setHeaderResizeHandleStyle(style: VolvoxGridHeaderResizeHandleStyle): void;
    setIconThemeSlots(slots: VolvoxGridIconThemeSlots): void;
    getIconThemeSlots(): VolvoxGridIconThemeSlots;
    getHeaderSeparator(): VolvoxGridHeaderSeparator;
    getHeaderResizeHandle(): VolvoxGridHeaderResizeHandle;
    getHeaderSeparatorStyle(): VolvoxGridHeaderSeparatorStyle;
    getHeaderResizeHandleStyle(): VolvoxGridHeaderResizeHandleStyle;

    setColSticky(col: number, edge: number): void;
    pinRow(row: number, pin: number): void;
    pinCol(col: number, pin: number): void;
    isColPinned(col: number): number;

    sort(order: number, col: number): void;
    sortMulti(cols: number[], orders: number[]): void;
    autoSize(colFrom?: number, colTo?: number, equal?: boolean, maxWidth?: number): void;
    moveColumn(col: number, position: number): void;
    setEventDecisionEnabled(enabled: boolean): void;
    sendEventDecision(eventId: bigint, cancel: boolean): boolean;
    sendRawEventDecision(rawEvent: Uint8Array, cancel: boolean): boolean;
    drainEventStreamRaw(maxEvents?: number): Uint8Array[];
    flushPendingEventDecisions(): boolean;
  }
}
