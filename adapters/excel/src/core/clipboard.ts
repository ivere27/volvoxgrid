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
  private cutRange: CellRange | null = null;
  private lastCopiedRange: CellRange | null = null;
  private lastCopiedData: string[][] | null = null;
  private lastCopiedTsv: string | null = null;

  constructor(store: DataStore, undoStack: UndoRedoStack) {
    this.store = store;
    this.undoStack = undoStack;
  }

  /** Copy selected range to clipboard as TSV. */
  async copy(range: CellRange): Promise<void> {
    this.cutRange = null;
    const copiedData = this.captureRangeRaw(range);
    const tsv = this.rowsToTsv(copiedData);
    const html = this.rangeToHtml(range);
    this.lastCopiedRange = { ...range };
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
  async cut(range: CellRange): Promise<void> {
    await this.copy(range);
    this.cutRange = { ...range };
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
      && this.lastCopiedRange != null
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
        if (internalCopyMatch && this.lastCopiedRange) {
          const sourceRow = this.lastCopiedRange.row1 + r;
          const sourceCol = this.lastCopiedRange.col1 + c;
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

    // If this was a cut, clear the original range
    if (this.cutRange) {
      for (let r = this.cutRange.row1; r <= this.cutRange.row2; r++) {
        for (let c = this.cutRange.col1; c <= this.cutRange.col2; c++) {
          const oldValue = this.store.getCellRawValue(r, c);
          if (oldValue !== "") {
            commands.push(new CellValueChange(this.store, r, c, oldValue, ""));
          }
        }
      }
      this.cutRange = null;
    }

    if (commands.length > 0) {
      this.undoStack.execute(new BatchCommand(commands, "Paste"));
    }
  }

  private rangeToTsv(range: CellRange): string {
    return this.rowsToTsv(this.captureRangeRaw(range));
  }

  private captureRangeRaw(range: CellRange): string[][] {
    const rows: string[][] = [];
    for (let r = range.row1; r <= range.row2; r++) {
      const cells: string[] = [];
      for (let c = range.col1; c <= range.col2; c++) {
        cells.push(this.store.getCellRawValue(r, c));
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

  private rangeToHtml(range: CellRange): string {
    let html = "<table>";
    for (let r = range.row1; r <= range.row2; r++) {
      html += "<tr>";
      for (let c = range.col1; c <= range.col2; c++) {
        const value = this.store.getCellRawValue(r, c);
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
}
