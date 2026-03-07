import type { VolvoxGrid } from "volvoxgrid";

export type VolvoxExcelGrid = VolvoxGrid & {
  rowCount: number;
  colCount: number;
  selectionMode: number;
  defaultRowHeight: number;
  defaultColWidth: number;
  showColumnHeaders: boolean;
  columnIndicatorTopRowCount: number;
  showRowIndicator: boolean;
  rowIndicatorStartModeBits: number;
  rowIndicatorStartWidth: number;
  frozenRowCount: number;
  frozenColCount: number;
  allowUserResizing: number;
  editTrigger: number;
  setCellText(row: number, col: number, text: string): void;
  getSelection(): {
    row: number;
    col: number;
    rowEnd: number;
    colEnd: number;
    ranges: CellRange[];
  };
  selectRanges(ranges: ReadonlyArray<CellRange>, activeRow?: number, activeCol?: number, show?: boolean): void;
  setColumnCaption(col: number, caption: string): void;
};

// ── Cell References ────────────────────────────────────────

export interface CellRef {
  row: number;
  col: number;
}

export interface CellRange {
  row1: number;
  col1: number;
  row2: number;
  col2: number;
}

// ── Cell Styling ───────────────────────────────────────────

export interface CellStyleUpdate {
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  fontName?: string;
  fontSize?: number;
  foreColor?: number;   // ARGB uint32
  backColor?: number;   // ARGB uint32
  alignment?: number;   // Align enum from proto
  // Per-edge borders
  borderTop?: number;   // BorderStyle enum
  borderRight?: number;
  borderBottom?: number;
  borderLeft?: number;
  borderColor?: number; // ARGB uint32 applied to all edges
}

// ── Key Dispatch ───────────────────────────────────────────

export type SpreadsheetAction =
  // Idle actions
  | "startEdit"
  | "startEditCaretEnd"
  | "startEditClear"
  | "clearCell"
  | "moveDown"
  | "moveUp"
  | "moveRight"
  | "moveLeft"
  // Editing actions
  | "commitMoveDown"
  | "commitMoveUp"
  | "commitMoveRight"
  | "commitMoveLeft"
  | "cancelEdit"
  // Common actions (both contexts)
  | "undo"
  | "redo"
  | "copy"
  | "cut"
  | "paste"
  | "selectAll"
  | "toggleBold"
  | "toggleItalic"
  | "toggleUnderline"
  | "deleteRow"
  | "insertRow"
  | "find"
  | "findReplace"
  | "noop";

export type KeyContext = "idle" | "editing";

export interface KeyBinding {
  key: string;       // e.g. "Enter", "Ctrl+Z", "Shift+Tab"
  context: KeyContext;
  action: SpreadsheetAction;
}

// ── Options ────────────────────────────────────────────────

export interface VolvoxExcelOptions {
  container: HTMLElement;
  wasm: any;
  rows?: number;
  cols?: number;
  data?: string[][];
  keyBindings?: Record<string, SpreadsheetAction>;
  showFormulaBar?: boolean;
  showToolbar?: boolean;
  defaultColWidth?: number;
  defaultRowHeight?: number;
  fontName?: string;
  fontSize?: number;
  /** URL to a .ttf/.otf font file for the grid engine. Defaults to Roboto from CDN. */
  fontUrl?: string;
}

// ── Public API ─────────────────────────────────────────────

export interface VolvoxExcelApi {
  readonly grid: VolvoxExcelGrid;

  // Data
  getCellValue(row: number, col: number): string;
  getCellRawValue(row: number, col: number): string;
  getCellFormula(row: number, col: number): string | null;
  setCellValue(row: number, col: number, value: string): void;
  getData(): string[][];
  setData(data: string[][]): void;
  clearRange(range: CellRange): void;

  // Selection
  getSelection(): CellRange;
  setSelection(range: CellRange): void;
  getActiveCell(): CellRef;

  // Formatting
  setCellStyle(row: number, col: number, style: CellStyleUpdate): void;
  setRangeStyle(range: CellRange, style: CellStyleUpdate): void;

  // Structure
  insertRows(index: number, count?: number): void;
  deleteRows(index: number, count?: number): void;
  insertColumns(index: number, count?: number): void;
  deleteColumns(index: number, count?: number): void;
  setColumnWidth(col: number, width: number): void;
  setRowHeight(row: number, height: number): void;
  mergeCells(range: CellRange): void;
  unmergeCells(range: CellRange): void;
  getMergedRegions(): CellRange[];
  freezeRows(count: number): void;
  freezeColumns(count: number): void;

  // Undo/Redo
  undo(): void;
  redo(): void;

  // Clipboard
  copy(): void;
  cut(): void;
  paste(text?: string): void;

  // Lifecycle
  resize(): void;
  destroy(): void;
}

// ── Undo/Redo ──────────────────────────────────────────────

export interface UndoableCommand {
  execute(): void;
  undo(): void;
  description: string;
}

// ── Events ─────────────────────────────────────────────────

export interface ExcelSelectionChangedDetail {
  row: number;
  col: number;
  ref: string;   // "A1" style
}

export interface ExcelCellEditDetail {
  row: number;
  col: number;
  oldText: string;
  newText: string;
}
