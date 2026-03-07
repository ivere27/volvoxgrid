/**
 * Copy/cut/paste with TSV + HTML clipboard support.
 */

import type { DataStore } from "./data-store.js";
import type { CellRange } from "../types.js";
import type { UndoRedoStack } from "./undo-redo.js";
import { CellValueChange, BatchCommand } from "./undo-redo.js";
import { FormulaEngine } from "./formula-engine.js";

export class ClipboardManager {
  private store: DataStore;
  private undoStack: UndoRedoStack;
  private cutRanges: CellRange[] | null = null;
  private lastCopiedRanges: CellRange[] | null = null;
  private lastCopiedBoundingRange: CellRange | null = null;
  private lastCopiedData: string[][] | null = null;
  private lastCopiedTsv: string | null = null;

  constructor(store: DataStore, undoStack: UndoRedoStack) {
    this.store = store;
    this.undoStack = undoStack;
  }

  /** Copy selected ranges to clipboard as TSV/HTML. */
  async copy(ranges: ReadonlyArray<CellRange>): Promise<void> {
    const normalizedRanges = this.normalizeRanges(ranges);
    if (normalizedRanges.length === 0) return;

    this.cutRanges = null;
    const boundingRange = this.getBoundingRange(normalizedRanges);
    const copiedData = this.captureRangesRaw(normalizedRanges, boundingRange);
    const tsv = this.rowsToTsv(copiedData);
    const html = this.rowsToHtml(copiedData);
    this.lastCopiedRanges = normalizedRanges.map((range) => ({ ...range }));
    this.lastCopiedBoundingRange = { ...boundingRange };
    this.lastCopiedData = copiedData.map((row) => [...row]);
    this.lastCopiedTsv = tsv;

    try {
      await navigator.clipboard.write([
        new ClipboardItem({
          "text/plain": new Blob([tsv], { type: "text/plain" }),
          "text/html": new Blob([html], { type: "text/html" }),
        }),
      ]);
    } catch {
      // Fallback for older browsers / denied clipboard permissions.
      // Internal copy memory still works even if writes fail.
      try {
        await navigator.clipboard.writeText(tsv);
      } catch {
        // no-op
      }
    }
  }

  /** Cut selected range (copy + mark for clear on paste). */
  async cut(ranges: ReadonlyArray<CellRange>): Promise<void> {
    const normalizedRanges = this.normalizeRanges(ranges);
    if (normalizedRanges.length === 0) return;
    await this.copy(normalizedRanges);
    this.cutRanges = normalizedRanges.map((range) => ({ ...range }));
  }

  /** Paste from clipboard text at the given cell position. */
  async paste(dataRow: number, dataCol: number, text?: string): Promise<void> {
    let pasteText = text;
    if (pasteText == null) {
      try {
        pasteText = await navigator.clipboard.readText();
      } catch {
        if (this.lastCopiedTsv != null) {
          pasteText = this.lastCopiedTsv;
        } else {
          return;
        }
      }
    }
    if (!pasteText) return;

    const internalCopyMatch =
      text == null
      && this.lastCopiedTsv != null
      && this.lastCopiedBoundingRange != null
      && this.lastCopiedData != null
      && pasteText === this.lastCopiedTsv;

    const rows = internalCopyMatch
      ? (this.lastCopiedData ?? []).map((row) => [...row])
      : this.parseTsv(pasteText);
    const commands: CellValueChange[] = [];

    for (let r = 0; r < rows.length; r++) {
      for (let c = 0; c < rows[r].length; c++) {
        const targetRow = dataRow + r;
        const targetCol = dataCol + c;
        const oldValue = this.store.getCellRawValue(targetRow, targetCol);
        let newValue = rows[r][c];
        if (internalCopyMatch && this.lastCopiedBoundingRange) {
          const sourceRow = this.lastCopiedBoundingRange.row1 + r;
          const sourceCol = this.lastCopiedBoundingRange.col1 + c;
          if (FormulaEngine.isFormula(newValue)) {
            newValue = FormulaEngine.rewriteReferencesByOffset(
              newValue,
              targetRow - sourceRow,
              targetCol - sourceCol,
            );
          }
        }
        if (oldValue !== newValue) {
          commands.push(new CellValueChange(this.store, targetRow, targetCol, oldValue, newValue));
        }
      }
    }

    // If this was a cut, clear the original selected cells.
    if (this.cutRanges) {
      for (const range of this.cutRanges) {
        for (let r = range.row1; r <= range.row2; r++) {
          for (let c = range.col1; c <= range.col2; c++) {
            const oldValue = this.store.getCellRawValue(r, c);
            if (oldValue !== "") {
              commands.push(new CellValueChange(this.store, r, c, oldValue, ""));
            }
          }
        }
      }
      this.cutRanges = null;
    }

    if (commands.length > 0) {
      this.undoStack.execute(new BatchCommand(commands, "Paste"));
    }
  }

  private captureRangesRaw(ranges: ReadonlyArray<CellRange>, boundingRange: CellRange): string[][] {
    const rows: string[][] = [];
    for (let r = boundingRange.row1; r <= boundingRange.row2; r++) {
      const cells: string[] = [];
      for (let c = boundingRange.col1; c <= boundingRange.col2; c++) {
        const included = ranges.some((range) =>
          r >= range.row1 && r <= range.row2 && c >= range.col1 && c <= range.col2,
        );
        cells.push(included ? this.store.getCellRawValue(r, c) : "");
      }
      rows.push(cells);
    }
    return rows;
  }

  private rowsToTsv(rows: string[][]): string {
    const lines: string[] = [];
    for (const row of rows) {
      lines.push(row.join("\t"));
    }
    return lines.join("\n");
  }

  private rowsToHtml(rows: string[][]): string {
    let html = "<table>";
    for (const row of rows) {
      html += "<tr>";
      for (const value of row) {
        html += `<td>${this.escapeHtml(value)}</td>`;
      }
      html += "</tr>";
    }
    html += "</table>";
    return html;
  }

  private escapeHtml(text: string): string {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  private parseTsv(text: string): string[][] {
    return text.split(/\r?\n/).map(line => line.split("\t"));
  }

  private normalizeRanges(ranges: ReadonlyArray<CellRange>): CellRange[] {
    return ranges.map((range) => ({
      row1: Math.min(range.row1, range.row2),
      col1: Math.min(range.col1, range.col2),
      row2: Math.max(range.row1, range.row2),
      col2: Math.max(range.col1, range.col2),
    }));
  }

  private getBoundingRange(ranges: ReadonlyArray<CellRange>): CellRange {
    let row1 = ranges[0].row1;
    let col1 = ranges[0].col1;
    let row2 = ranges[0].row2;
    let col2 = ranges[0].col2;
    for (const range of ranges) {
      row1 = Math.min(row1, range.row1);
      col1 = Math.min(col1, range.col1);
      row2 = Math.max(row2, range.row2);
      col2 = Math.max(col2, range.col2);
    }
    return { row1, col1, row2, col2 };
  }
}
