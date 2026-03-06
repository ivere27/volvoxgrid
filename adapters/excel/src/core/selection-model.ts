/**
 * Spreadsheet selection model.
 *
 * Tracks the current selection and provides methods for navigation.
 * Coordinates are in grid/data space.
 */

import type { CellRef, CellRange, VolvoxExcelGrid } from "../types.js";
import { encodeSelectRequest } from "../proto/proto-utils.js";
import { toA1, colToLetter } from "./cell-reference.js";

export class SelectionModel {
  private wasm: any;
  private gridId: number;
  private _grid: VolvoxExcelGrid;

  /** Current active cell in grid space. */
  private _row: number = 0;
  private _col: number = 0;
  /** Range end (for multi-cell selection). */
  private _rowEnd: number = 0;
  private _colEnd: number = 0;

  constructor(wasm: any, gridId: number, grid: VolvoxExcelGrid) {
    this.wasm = wasm;
    this.gridId = gridId;
    this._grid = grid;
  }

  get row(): number { return this._row; }
  get col(): number { return this._col; }
  get rowEnd(): number { return this._rowEnd; }
  get colEnd(): number { return this._colEnd; }

  /** Active cell in data space (0-based). */
  get dataRow(): number { return this._row; }
  get dataCol(): number { return this._col; }

  /** A1 reference of the active cell or range (e.g. "A1" or "A1:C3"). */
  get a1Ref(): string {
    if (this._row === this._rowEnd && this._col === this._colEnd) {
      return toA1(this.dataRow, this.dataCol);
    }
    const r1 = Math.min(this._row, this._rowEnd);
    const c1 = Math.min(this._col, this._colEnd);
    const r2 = Math.max(this._row, this._rowEnd);
    const c2 = Math.max(this._col, this._colEnd);
    return `${colToLetter(c1)}${r1 + 1}:${colToLetter(c2)}${r2 + 1}`;
  }

  /** Get selection as a CellRange in data space. */
  getRange(): CellRange {
    const r1 = Math.min(this._row, this._rowEnd);
    const c1 = Math.min(this._col, this._colEnd);
    const r2 = Math.max(this._row, this._rowEnd);
    const c2 = Math.max(this._col, this._colEnd);
    return { row1: r1, col1: c1, row2: r2, col2: c2 };
  }

  /** Get active cell in data space. */
  getActiveCell(): CellRef {
    return { row: this.dataRow, col: this.dataCol };
  }

  /** Navigate selection via WASM. */
  select(row: number, col: number, rowEnd?: number, colEnd?: number, show: boolean = true): void {
    this._row = row;
    this._col = col;
    this._rowEnd = rowEnd ?? row;
    this._colEnd = colEnd ?? col;

    if (typeof this.wasm.volvox_grid_select_pb === "function") {
      const req = encodeSelectRequest({
        gridId: this.gridId,
        row,
        col,
        rowEnd,
        colEnd,
        show,
      });
      this.wasm.volvox_grid_select_pb(req);
    }
  }

  /** Move active cell by delta, clamped to grid bounds. */
  move(dRow: number, dCol: number): void {
    const newRow = Math.max(0, Math.min(this._grid.rows - 1, this._row + dRow));
    const newCol = Math.max(0, Math.min(this._grid.cols - 1, this._col + dCol));
    this.select(newRow, newCol);
  }

  /** Set selection from a data-space CellRange. */
  setFromDataRange(range: CellRange): void {
    this.select(
      range.row1,
      range.col1,
      range.row2,
      range.col2,
    );
  }

  /** Update cursor position from engine CellFocusChanged events. */
  onSelectionChanged(row: number, col: number): void {
    this._row = row;
    this._col = col;
    this._rowEnd = row;
    this._colEnd = col;
  }

  /** Update range end from engine SelectionChanged events (cursor stays). */
  onSelectionEndChanged(rowEnd: number, colEnd: number): void {
    this._rowEnd = rowEnd;
    this._colEnd = colEnd;
  }
}
