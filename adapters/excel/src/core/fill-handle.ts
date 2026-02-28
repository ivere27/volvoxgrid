/**
 * Fill handle: drag the selection corner to fill cells.
 *
 * The visual fill-handle square is rendered natively by the engine
 * (render_fill_handle in canvas.rs). This class handles hit-testing
 * and the drag/fill business logic.
 */

import type { VolvoxGrid } from "volvoxgrid";
import type { DataStore } from "./data-store.js";
import type { SelectionModel } from "./selection-model.js";
import type { UndoRedoStack } from "./undo-redo.js";
import { CellValueChange, BatchCommand } from "./undo-redo.js";
import { FormulaEngine } from "./formula-engine.js";

export class FillHandle {
  private canvas: HTMLCanvasElement;
  private wasm: any;
  private grid: VolvoxGrid;
  private store: DataStore;
  private selection: SelectionModel;
  private undoStack: UndoRedoStack;

  private dragging = false;
  private dragEndRow = 0;
  private dragEndCol = 0;

  constructor(
    canvas: HTMLCanvasElement,
    wasm: any,
    grid: VolvoxGrid,
    store: DataStore,
    selection: SelectionModel,
    undoStack: UndoRedoStack,
  ) {
    this.canvas = canvas;
    this.wasm = wasm;
    this.grid = grid;
    this.store = store;
    this.selection = selection;
    this.undoStack = undoStack;
  }

  /**
   * Hit-test: is the device-pixel coordinate over the 7px fill-handle square?
   * Returns true if (px, py) falls within the handle area at the selection's
   * bottom-right cell corner.
   */
  hitTestFillHandle(px: number, py: number): boolean {
    try {
      const range = this.selection.getRange();
      const gridRow = range.row2 + this.grid.fixedRows;
      const gridCol = range.col2 + this.grid.fixedCols;
      const gridId = this.grid.id;

      const cx = Number(this.wasm.get_cell_screen_x(gridId, gridRow, gridCol));
      const cy = Number(this.wasm.get_cell_screen_y(gridId, gridRow, gridCol));
      const cw = Number(this.wasm.get_cell_screen_w(gridId, gridRow, gridCol));
      const ch = Number(this.wasm.get_cell_screen_h(gridId, gridRow, gridCol));

      if (cx < 0 || cy < 0 || cw <= 0 || ch <= 0) return false;

      // Match the engine's render_fill_handle geometry:
      // 7-device-pixel square centered on cell's bottom-right corner
      const size = 7;
      const half = Math.floor(size / 2); // 3
      const anchorX = cx + cw - 1;
      const anchorY = cy + ch - 1;
      const sx = anchorX - half;
      const sy = anchorY - half;

      return px >= sx && px < sx + size && py >= sy && py < sy + size;
    } catch {
      return false;
    }
  }

  /** Begin fill-drag from the fill handle. */
  startDrag(): void {
    this.dragging = true;
    const range = this.selection.getRange();
    this.dragEndRow = range.row2;
    this.dragEndCol = range.col2;

    document.addEventListener("pointermove", this.onPointerMove);
    document.addEventListener("pointerup", this.onPointerUp);
  }

  get isDragging(): boolean {
    return this.dragging;
  }

  private onPointerMove = (e: PointerEvent): void => {
    if (!this.dragging) return;
    const rect = this.canvas.getBoundingClientRect();
    // Engine expects device pixels
    const dpr = window.devicePixelRatio || 1;
    const px = (e.clientX - rect.left) * dpr;
    const py = (e.clientY - rect.top) * dpr;
    const gridId = this.grid.id;
    const fixedRows = this.grid.fixedRows;
    const fixedCols = this.grid.fixedCols;
    const gridRow = Number(this.wasm.hit_test_row(gridId, px, py));
    const gridCol = Number(this.wasm.hit_test_col(gridId, px, py));
    const dataRow = gridRow - fixedRows;
    const dataCol = gridCol - fixedCols;
    if (dataRow >= 0) this.dragEndRow = dataRow;
    if (dataCol >= 0) this.dragEndCol = dataCol;
  };

  private onPointerUp = (): void => {
    document.removeEventListener("pointermove", this.onPointerMove);
    document.removeEventListener("pointerup", this.onPointerUp);
    this.dragging = false;
    this.executeFill();
  };

  private executeFill(): void {
    const range = this.selection.getRange();
    const srcRow1 = range.row1;
    const srcCol1 = range.col1;
    const srcRow2 = range.row2;
    const srcCol2 = range.col2;
    const srcRows = srcRow2 - srcRow1 + 1;
    const srcCols = srcCol2 - srcCol1 + 1;

    const commands: CellValueChange[] = [];

    if (this.dragEndRow > srcRow2) {
      // Fill down
      for (let r = srcRow2 + 1; r <= this.dragEndRow; r++) {
        for (let c = srcCol1; c <= srcCol2; c++) {
          const fillVal = this.detectFillValue(srcRow1, c, srcRows, r - srcRow1, r);
          const old = this.store.getCellRawValue(r, c);
          if (old !== fillVal) {
            commands.push(new CellValueChange(this.store, r, c, old, fillVal));
          }
        }
      }
    } else if (this.dragEndRow < srcRow1) {
      // Fill up
      for (let r = srcRow1 - 1; r >= this.dragEndRow; r--) {
        for (let c = srcCol1; c <= srcCol2; c++) {
          const fillVal = this.detectFillValue(srcRow1, c, srcRows, r - srcRow1, r);
          const old = this.store.getCellRawValue(r, c);
          if (old !== fillVal) {
            commands.push(new CellValueChange(this.store, r, c, old, fillVal));
          }
        }
      }
    } else if (this.dragEndCol > srcCol2) {
      // Fill right
      for (let r = srcRow1; r <= srcRow2; r++) {
        for (let c = srcCol2 + 1; c <= this.dragEndCol; c++) {
          const srcCol = srcCol1 + this.positiveMod(c - srcCol1, srcCols);
          const fillVal = this.resolveFilledRawValue(r, srcCol, r, c);
          const old = this.store.getCellRawValue(r, c);
          if (old !== fillVal) {
            commands.push(new CellValueChange(this.store, r, c, old, fillVal));
          }
        }
      }
    } else if (this.dragEndCol < srcCol1) {
      // Fill left
      for (let r = srcRow1; r <= srcRow2; r++) {
        for (let c = srcCol1 - 1; c >= this.dragEndCol; c--) {
          const srcCol = srcCol1 + this.positiveMod(c - srcCol1, srcCols);
          const fillVal = this.resolveFilledRawValue(r, srcCol, r, c);
          const old = this.store.getCellRawValue(r, c);
          if (old !== fillVal) {
            commands.push(new CellValueChange(this.store, r, c, old, fillVal));
          }
        }
      }
    }

    if (commands.length > 0) {
      this.undoStack.execute(new BatchCommand(commands, "Fill"));
    }
  }

  private positiveMod(value: number, modulus: number): number {
    const mod = value % modulus;
    return mod < 0 ? mod + modulus : mod;
  }

  /** Detect numeric sequence and return extrapolated value, or copy cyclically. */
  private detectFillValue(
    srcRow: number,
    col: number,
    srcCount: number,
    offset: number,
    targetRow: number,
  ): string {
    if (srcCount >= 2) {
      const vals: number[] = [];
      for (let i = 0; i < srcCount; i++) {
        const raw = this.store.getCellRawValue(srcRow + i, col);
        if (FormulaEngine.isFormula(raw)) {
          vals.length = 0;
          break;
        }
        const v = Number(this.store.getCellValue(srcRow + i, col));
        if (!Number.isFinite(v)) {
          vals.length = 0;
          break;
        }
        vals.push(v);
      }

      if (vals.length === srcCount) {
        const diff = vals[1] - vals[0];
        let isArithmetic = true;
        for (let i = 2; i < vals.length; i++) {
          if (Math.abs((vals[i] - vals[i - 1]) - diff) > 1e-10) {
            isArithmetic = false;
            break;
          }
        }
        if (isArithmetic) {
          return String(vals[0] + diff * offset);
        }
      }
    }

    const sourceRow = srcRow + this.positiveMod(offset, srcCount);
    return this.resolveFilledRawValue(sourceRow, col, targetRow, col);
  }

  private resolveFilledRawValue(
    sourceRow: number,
    sourceCol: number,
    targetRow: number,
    targetCol: number,
  ): string {
    const raw = this.store.getCellRawValue(sourceRow, sourceCol);
    if (!FormulaEngine.isFormula(raw)) return raw;
    return FormulaEngine.rewriteReferencesByOffset(
      raw,
      targetRow - sourceRow,
      targetCol - sourceCol,
    );
  }

  destroy(): void {
    document.removeEventListener("pointermove", this.onPointerMove);
    document.removeEventListener("pointerup", this.onPointerUp);
  }
}
