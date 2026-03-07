declare module "volvoxgrid" {
  export type VolvoxGridHeaderMarkHeight =
    | { mode: "ratio"; value: number }
    | { mode: "px"; value: number };

  export interface VolvoxGridHeaderSeparatorStyle {
    enabled?: boolean;
    colorArgb?: number;
    widthPx?: number;
    height?: VolvoxGridHeaderMarkHeight;
    skipMerged?: boolean;
  }

  export interface VolvoxGridHeaderResizeHandleStyle {
    enabled?: boolean;
    colorArgb?: number;
    widthPx?: number;
    height?: VolvoxGridHeaderMarkHeight;
    hitWidthPx?: number;
    showOnlyWhenResizable?: boolean;
  }

  export interface VolvoxGridIconThemeSlots {
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

  export type VolvoxGridIconSlotName = keyof VolvoxGridIconThemeSlots;

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
    headerFeatures: number;
    allowUserResizing: number;
    allowUserFreezing: number;
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
    setIconTheme(theme: VolvoxGridIconTheme): void;
    getIconTheme(): VolvoxGridIconTheme;
    setHeaderSeparatorStyle(style: VolvoxGridHeaderSeparatorStyle): void;
    setHeaderResizeHandleStyle(style: VolvoxGridHeaderResizeHandleStyle): void;
    setIconThemeSlots(slots: VolvoxGridIconThemeSlots): void;
    getIconThemeSlots(): VolvoxGridIconThemeSlots;
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
    drainEventStreamRaw(maxEvents?: number): Uint8Array[];
  }
}
