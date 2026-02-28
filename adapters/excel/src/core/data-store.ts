/**
 * Parallel data model + header generation for the spreadsheet.
 *
 * Maintains a shadow copy of cell values for undo/redo and clipboard
 * operations. Generates A/B/C column headers and 1/2/3 row numbers.
 */

import type { VolvoxGrid } from "volvoxgrid";
import type { CellRange } from "../types.js";
import { generateColumnHeaders, generateRowNumbers } from "./cell-reference.js";
import { FormulaEngine, type FormulaRefShift } from "./formula-engine.js";
import {
  encodeUpdateCellsRequest,
  type CellUpdateEntry,
} from "../proto/proto-utils.js";

export class DataStore {
  private wasm: any;
  private gridId: number;
  private _grid: VolvoxGrid;

  /** Display data: dataRows × dataCols (0-based, excluding headers). */
  private data: string[][] = [];
  /** Raw user-entered values (formula text kept as-is). */
  private rawData: string[][] = [];

  constructor(wasm: any, gridId: number, grid: VolvoxGrid) {
    this.wasm = wasm;
    this.gridId = gridId;
    this._grid = grid;
  }

  get dataRows(): number { return this._grid.rows - this._grid.fixedRows; }
  get dataCols(): number { return this._grid.cols - this._grid.fixedCols; }

  /** Initialize headers and populate grid with data. */
  init(initialData?: string[][]): void {
    this.populateHeaders();
    if (initialData) {
      this.setData(initialData);
    } else {
      this.ensureShadowSize();
    }
  }

  /** Populate column headers (A, B, C...) and row numbers (1, 2, 3...). */
  populateHeaders(): void {
    const fixedRows = this._grid.fixedRows;
    const fixedCols = this._grid.fixedCols;

    // Column headers in row 0
    if (fixedRows > 0) {
      const headers = generateColumnHeaders(this.dataCols);
      for (let c = 0; c < headers.length; c++) {
        this._grid.setTextMatrix(0, c + fixedCols, headers[c]);
      }
      // Corner cell (row 0, col 0) left blank
    }

    // Row numbers in col 0
    if (fixedCols > 0) {
      const rowNums = generateRowNumbers(this.dataRows);
      for (let r = 0; r < rowNums.length; r++) {
        this._grid.setTextMatrix(r + fixedRows, 0, rowNums[r]);
      }
    }
  }

  /** Get a cell value in data space. */
  getCellValue(dataRow: number, dataCol: number): string {
    return this.data[dataRow]?.[dataCol] ?? "";
  }

  /** Get full display data (evaluated values). */
  getDisplayData(): string[][] {
    this.ensureShadowSize();
    return this.data.map(row => [...row]);
  }

  /** Get raw cell input in data space (formula text if present). */
  getCellRawValue(dataRow: number, dataCol: number): string {
    return this.rawData[dataRow]?.[dataCol] ?? "";
  }

  /** Get raw formula text for a cell, or null if not a formula. */
  getCellFormula(dataRow: number, dataCol: number): string | null {
    const raw = this.getCellRawValue(dataRow, dataCol);
    return FormulaEngine.isFormula(raw) ? raw : null;
  }

  /** Set a cell value in data space. Updates both shadow and grid. */
  setCellValue(dataRow: number, dataCol: number, value: string): void {
    this.ensureShadowCell(dataRow, dataCol);
    this.rawData[dataRow][dataCol] = value;
    this.recalculateAndRender(false);
  }

  /** Set cell value and push to engine via protobuf (for undo operations). */
  setCellValuePb(dataRow: number, dataCol: number, value: string): void {
    this.ensureShadowCell(dataRow, dataCol);
    this.rawData[dataRow][dataCol] = value;
    this.recalculateAndRender(true);
  }

  /** Batch update cells via protobuf. */
  batchUpdateCells(updates: CellUpdateEntry[]): void {
    if (typeof this.wasm.volvox_grid_update_cells_pb === "function") {
      const req = encodeUpdateCellsRequest({ gridId: this.gridId, updates });
      this.wasm.volvox_grid_update_cells_pb(req);
    }
  }

  /** Get all raw user-entered data as a 2D string array. */
  getData(): string[][] {
    this.ensureShadowSize();
    return this.rawData.map(row => [...row]);
  }

  /** Replace all data. */
  setData(newData: string[][]): void {
    this.rawData = [];
    this.data = [];
    for (let r = 0; r < this.dataRows; r++) {
      const rawRow: string[] = [];
      const displayRow: string[] = [];
      for (let c = 0; c < this.dataCols; c++) {
        rawRow.push(newData[r]?.[c] ?? "");
        displayRow.push("");
      }
      this.rawData.push(rawRow);
      this.data.push(displayRow);
    }
    this.recalculateAndRender(false, true);
  }

  /** Clear a range in data space. */
  clearRange(range: CellRange): void {
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        this.setCellValue(r, c, "");
      }
    }
  }

  /** Sync shadow from engine after edit events. */
  onCellEdited(dataRow: number, dataCol: number, newText: string): void {
    this.ensureShadowCell(dataRow, dataCol);
    this.rawData[dataRow][dataCol] = newText;
    this.recalculateAndRender(true);
  }

  /** After inserting rows, update row numbers. */
  onRowsInserted(dataIndex: number, count: number): void {
    // Insert empty rows into shadow
    for (let i = 0; i < count; i++) {
      const emptyRow = new Array(this.dataCols).fill("");
      this.data.splice(dataIndex + i, 0, emptyRow);
      this.rawData.splice(dataIndex + i, 0, new Array(this.dataCols).fill(""));
    }
    this.ensureShadowSize();
    this.rewriteFormulaReferences({ kind: "insertRows", index: dataIndex, count });
    this.recalculateAndRender(false);
    this.refreshRowNumbers();
  }

  /** After deleting rows, update row numbers. */
  onRowsDeleted(dataIndex: number, count: number): void {
    this.data.splice(dataIndex, count);
    this.rawData.splice(dataIndex, count);
    this.ensureShadowSize();
    this.rewriteFormulaReferences({ kind: "deleteRows", index: dataIndex, count });
    this.recalculateAndRender(false);
    this.refreshRowNumbers();
  }

  /** After inserting columns, shift data right (last column falls off the end). */
  onColsInserted(dataIndex: number, count: number): void {
    for (const row of this.data) {
      const empties = new Array(count).fill("");
      row.splice(dataIndex, 0, ...empties);
      // Trim back to dataCols — rightmost data falls off the fixed grid boundary
      row.length = this.dataCols;
    }
    for (const row of this.rawData) {
      const empties = new Array(count).fill("");
      row.splice(dataIndex, 0, ...empties);
      row.length = this.dataCols;
    }
    this.ensureShadowSize();
    this.rewriteFormulaReferences({ kind: "insertCols", index: dataIndex, count });
    this.recalculateAndRender(false);
    this.repopulateGrid();
  }

  /** After deleting columns, shift data left (tail becomes empty). */
  onColsDeleted(dataIndex: number, count: number): void {
    for (const row of this.data) {
      row.splice(dataIndex, count);
    }
    for (const row of this.rawData) {
      row.splice(dataIndex, count);
    }
    // Re-pad to full width so repopulateGrid clears the stale tail cells
    this.ensureShadowSize();
    this.rewriteFormulaReferences({ kind: "deleteCols", index: dataIndex, count });
    this.recalculateAndRender(false);
    this.repopulateGrid();
  }

  /** Re-push all shadow data to the grid (after structural column changes). */
  private repopulateGrid(): void {
    const fixedRows = this._grid.fixedRows;
    const fixedCols = this._grid.fixedCols;
    const cols = this.dataCols;
    for (let r = 0; r < this.data.length; r++) {
      for (let c = 0; c < cols; c++) {
        this._grid.setTextMatrix(r + fixedRows, c + fixedCols, this.data[r]?.[c] ?? "");
      }
    }
  }

  private refreshRowNumbers(): void {
    const fixedRows = this._grid.fixedRows;
    const fixedCols = this._grid.fixedCols;
    if (fixedCols > 0) {
      for (let r = 0; r < this.dataRows; r++) {
        this._grid.setTextMatrix(r + fixedRows, 0, String(r + 1));
      }
    }
  }

  private ensureShadowSize(): void {
    while (this.data.length < this.dataRows) {
      this.data.push(new Array(this.dataCols).fill(""));
    }
    while (this.rawData.length < this.dataRows) {
      this.rawData.push(new Array(this.dataCols).fill(""));
    }
    for (let r = 0; r < this.data.length; r++) {
      while (this.data[r].length < this.dataCols) {
        this.data[r].push("");
      }
    }
    for (let r = 0; r < this.rawData.length; r++) {
      while (this.rawData[r].length < this.dataCols) {
        this.rawData[r].push("");
      }
    }
  }

  private ensureShadowCell(dataRow: number, dataCol: number): void {
    while (this.data.length <= dataRow) {
      this.data.push([]);
    }
    while (this.rawData.length <= dataRow) {
      this.rawData.push([]);
    }
    while (this.data[dataRow].length <= dataCol) {
      this.data[dataRow].push("");
    }
    while (this.rawData[dataRow].length <= dataCol) {
      this.rawData[dataRow].push("");
    }
  }

  private rewriteFormulaReferences(shift: FormulaRefShift): void {
    for (let r = 0; r < this.rawData.length; r++) {
      for (let c = 0; c < this.rawData[r].length; c++) {
        const raw = this.rawData[r][c] ?? "";
        if (!FormulaEngine.isFormula(raw)) continue;
        const rewritten = FormulaEngine.rewriteReferences(raw, shift);
        if (rewritten !== raw) {
          this.rawData[r][c] = rewritten;
        }
      }
    }
  }

  private recalculateAndRender(usePb: boolean, forceAll = false): void {
    this.ensureShadowSize();

    const memo = new Map<string, string>();
    const visiting = new Set<string>();
    const updates: CellUpdateEntry[] = [];
    const fixedRows = this._grid.fixedRows;
    const fixedCols = this._grid.fixedCols;

    const evalCell = (dataRow: number, dataCol: number): string => {
      if (dataRow < 0 || dataCol < 0 || dataRow >= this.dataRows || dataCol >= this.dataCols) {
        return "#REF!";
      }
      const key = `${dataRow}:${dataCol}`;
      const cached = memo.get(key);
      if (cached != null) return cached;

      if (visiting.has(key)) return "#REF!";
      visiting.add(key);

      const raw = this.rawData[dataRow]?.[dataCol] ?? "";
      let value = raw;
      if (FormulaEngine.isFormula(raw)) {
        value = FormulaEngine.evaluate(raw, {
          getCellValue: (r, c) => evalCell(r, c),
          maxRows: this.dataRows,
          maxCols: this.dataCols,
        });
      }

      visiting.delete(key);
      memo.set(key, value);
      return value;
    };

    for (let r = 0; r < this.dataRows; r++) {
      for (let c = 0; c < this.dataCols; c++) {
        const nextDisplay = evalCell(r, c);
        if (forceAll || this.data[r][c] !== nextDisplay) {
          this.data[r][c] = nextDisplay;
          updates.push({
            row: r + fixedRows,
            col: c + fixedCols,
            text: nextDisplay,
          });
        }
      }
    }

    if (updates.length === 0) return;

    if (usePb && typeof this.wasm.volvox_grid_update_cells_pb === "function") {
      const req = encodeUpdateCellsRequest({
        gridId: this.gridId,
        updates,
      });
      this.wasm.volvox_grid_update_cells_pb(req);
      return;
    }

    for (const u of updates) {
      this._grid.setTextMatrix(u.row, u.col, u.text ?? "");
    }
  }
}
