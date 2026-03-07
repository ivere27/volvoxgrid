/**
 * Spreadsheet selection model.
 *
 * Tracks the current selection and provides methods for navigation.
 * Coordinates are in grid/data space.
 */

import type { CellRef, CellRange, VolvoxSheetGrid } from "../types.js";
import { encodeSelectRequest } from "../proto/proto-utils.js";
import { toA1, colToLetter } from "./cell-reference.js";

export class SelectionModel {
  private wasm: any;
  private gridId: number;
  private _grid: VolvoxSheetGrid;

  /** Current active cell in grid space. */
  private _row: number = 0;
  private _col: number = 0;
  /** Range end (for multi-cell selection). */
  private _rowEnd: number = 0;
  private _colEnd: number = 0;
  private _ranges: CellRange[] = [{ row1: 0, col1: 0, row2: 0, col2: 0 }];

  constructor(wasm: any, gridId: number, grid: VolvoxSheetGrid) {
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

  getRanges(): CellRange[] {
    return this._ranges.map((range) => ({ ...range }));
  }

  /** Navigate selection via WASM. */
  select(row: number, col: number, rowEnd?: number, colEnd?: number, show: boolean = true): void {
    this.selectRanges(
      [{
        row1: row,
        col1: col,
        row2: rowEnd ?? row,
        col2: colEnd ?? col,
      }],
      row,
      col,
      show,
    );
  }

  selectRanges(
    ranges: ReadonlyArray<CellRange>,
    activeRow: number = this._row,
    activeCol: number = this._col,
    show: boolean = true,
  ): void {
    const normalized = ranges.length > 0
      ? ranges.map((range) => this.normalizeRange(range))
      : [this.normalizeRange({ row1: activeRow, col1: activeCol, row2: activeRow, col2: activeCol })];

    if (typeof this._grid.selectRanges === "function") {
      this._grid.selectRanges(normalized, activeRow, activeCol, show);
      this.syncFromSnapshot(this._grid.getSelection());
      return;
    }

    if (typeof this.wasm.volvox_grid_select_pb === "function") {
      const req = encodeSelectRequest({
        gridId: this.gridId,
        row: activeRow,
        col: activeCol,
        ranges: normalized,
        show,
      });
      this.wasm.volvox_grid_select_pb(req);
    }

    this.syncFromRanges(activeRow, activeCol, normalized);
  }

  /** Move active cell by delta, clamped to grid bounds. */
  move(dRow: number, dCol: number): void {
    const newRow = Math.max(0, Math.min(this._grid.rowCount - 1, this._row + dRow));
    const newCol = Math.max(0, Math.min(this._grid.colCount - 1, this._col + dCol));
    this.select(newRow, newCol);
  }

  /** Set selection from a data-space CellRange. */
  setFromDataRange(range: CellRange): void {
    this.select(range.row1, range.col1, range.row2, range.col2);
  }

  /** Update cursor position from engine CellFocusChanged events. */
  onSelectionChanged(row: number, col: number): void {
    this._row = row;
    this._col = col;
    this._rowEnd = row;
    this._colEnd = col;
    this.refreshActiveRange();
  }

  /** Update range end from engine SelectionChanged events (cursor stays). */
  onSelectionEndChanged(rowEnd: number, colEnd: number): void {
    this._rowEnd = rowEnd;
    this._colEnd = colEnd;
    this.refreshActiveRange();
  }

  syncFromSnapshot(snapshot: {
    row: number;
    col: number;
    rowEnd: number;
    colEnd: number;
    ranges?: ReadonlyArray<CellRange>;
  }): void {
    const ranges = snapshot.ranges && snapshot.ranges.length > 0
      ? snapshot.ranges
      : [{
        row1: snapshot.row,
        col1: snapshot.col,
        row2: snapshot.rowEnd,
        col2: snapshot.colEnd,
      }];
    this.syncFromRanges(snapshot.row, snapshot.col, ranges);
  }

  matchesSnapshot(snapshot: {
    row: number;
    col: number;
    rowEnd: number;
    colEnd: number;
    ranges?: ReadonlyArray<CellRange>;
  }): boolean {
    if (
      snapshot.row !== this._row
      || snapshot.col !== this._col
      || snapshot.rowEnd !== this._rowEnd
      || snapshot.colEnd !== this._colEnd
    ) {
      return false;
    }
    const ranges = snapshot.ranges && snapshot.ranges.length > 0
      ? snapshot.ranges.map((range) => this.normalizeRange(range))
      : [this.normalizeRange({
        row1: snapshot.row,
        col1: snapshot.col,
        row2: snapshot.rowEnd,
        col2: snapshot.colEnd,
      })];
    if (ranges.length !== this._ranges.length) {
      return false;
    }
    return ranges.every((range, index) => {
      const current = this._ranges[index];
      return current.row1 === range.row1
        && current.col1 === range.col1
        && current.row2 === range.row2
        && current.col2 === range.col2;
    });
  }

  private syncFromRanges(
    activeRow: number,
    activeCol: number,
    ranges: ReadonlyArray<CellRange>,
  ): void {
    const normalized = ranges.length > 0
      ? ranges.map((range) => this.normalizeRange(range))
      : [this.normalizeRange({ row1: activeRow, col1: activeCol, row2: activeRow, col2: activeCol })];
    const clampedActiveRow = Math.max(0, Math.min(this._grid.rowCount - 1, activeRow));
    const clampedActiveCol = Math.max(0, Math.min(this._grid.colCount - 1, activeCol));
    let activeIndex = normalized.findIndex((range) =>
      (range.row1 === clampedActiveRow && range.col1 === clampedActiveCol)
      || (range.row2 === clampedActiveRow && range.col2 === clampedActiveCol),
    );
    if (activeIndex < 0) {
      activeIndex = 0;
    }
    const activeRange = normalized[activeIndex];
    if (activeRange.row1 === clampedActiveRow && activeRange.col1 === clampedActiveCol) {
      this._row = activeRange.row1;
      this._col = activeRange.col1;
      this._rowEnd = activeRange.row2;
      this._colEnd = activeRange.col2;
    } else if (activeRange.row2 === clampedActiveRow && activeRange.col2 === clampedActiveCol) {
      this._row = activeRange.row2;
      this._col = activeRange.col2;
      this._rowEnd = activeRange.row1;
      this._colEnd = activeRange.col1;
    } else {
      this._row = activeRange.row1;
      this._col = activeRange.col1;
      this._rowEnd = activeRange.row2;
      this._colEnd = activeRange.col2;
    }
    this._ranges = [
      activeRange,
      ...normalized.filter((_, index) => index !== activeIndex),
    ];
  }

  private refreshActiveRange(): void {
    const activeRange = this.normalizeRange({
      row1: this._row,
      col1: this._col,
      row2: this._rowEnd,
      col2: this._colEnd,
    });
    if (this._ranges.length === 0) {
      this._ranges = [activeRange];
      return;
    }
    this._ranges = [activeRange, ...this._ranges.slice(1)];
  }

  private normalizeRange(range: CellRange): CellRange {
    return {
      row1: Math.min(range.row1, range.row2),
      col1: Math.min(range.col1, range.col2),
      row2: Math.max(range.row1, range.row2),
      col2: Math.max(range.col1, range.col2),
    };
  }
}
