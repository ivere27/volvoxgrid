/**
 * Command-pattern undo/redo stack.
 */

import type { UndoableCommand } from "../types.js";

const MAX_UNDO_STACK = 100;

export class UndoRedoStack {
  private undoStack: UndoableCommand[] = [];
  private redoStack: UndoableCommand[] = [];

  /** Execute a command and push it onto the undo stack. */
  execute(command: UndoableCommand): void {
    command.execute();
    this.undoStack.push(command);
    if (this.undoStack.length > MAX_UNDO_STACK) {
      this.undoStack.shift();
    }
    this.redoStack.length = 0;
  }

  /** Push a command that was already executed (e.g. from engine edit). */
  pushExecuted(command: UndoableCommand): void {
    this.undoStack.push(command);
    if (this.undoStack.length > MAX_UNDO_STACK) {
      this.undoStack.shift();
    }
    this.redoStack.length = 0;
  }

  /** Undo the last command. */
  undo(): void {
    const command = this.undoStack.pop();
    if (!command) return;
    command.undo();
    this.redoStack.push(command);
  }

  /** Redo the last undone command. */
  redo(): void {
    const command = this.redoStack.pop();
    if (!command) return;
    command.execute();
    this.undoStack.push(command);
  }

  get canUndo(): boolean { return this.undoStack.length > 0; }
  get canRedo(): boolean { return this.redoStack.length > 0; }

  clear(): void {
    this.undoStack.length = 0;
    this.redoStack.length = 0;
  }
}

// ── Concrete commands ──────────────────────────────────────

import type { DataStore } from "./data-store.js";
import type { CellStyleFields } from "../proto/proto-utils.js";

export class CellValueChange implements UndoableCommand {
  description: string;
  constructor(
    private store: DataStore,
    private dataRow: number,
    private dataCol: number,
    private oldText: string,
    private newText: string,
  ) {
    this.description = `Set (${dataRow},${dataCol}) = "${newText}"`;
  }

  execute(): void {
    this.store.setCellValuePb(this.dataRow, this.dataCol, this.newText);
  }

  undo(): void {
    this.store.setCellValuePb(this.dataRow, this.dataCol, this.oldText);
  }
}

export class BatchCommand implements UndoableCommand {
  description: string;
  constructor(private commands: UndoableCommand[], desc?: string) {
    this.description = desc ?? `Batch (${commands.length} changes)`;
  }

  execute(): void {
    for (const cmd of this.commands) {
      cmd.execute();
    }
  }

  undo(): void {
    // Undo in reverse order
    for (let i = this.commands.length - 1; i >= 0; i--) {
      this.commands[i].undo();
    }
  }
}

export class SnapshotDataChange implements UndoableCommand {
  description: string;
  private beforeData: string[][];
  private afterData: string[][];

  constructor(
    private applySnapshot: (data: string[][]) => void,
    beforeData: string[][],
    afterData: string[][],
    description: string,
  ) {
    this.description = description;
    this.beforeData = beforeData.map((row) => [...row]);
    this.afterData = afterData.map((row) => [...row]);
  }

  execute(): void {
    this.applySnapshot(this.afterData.map((row) => [...row]));
  }

  undo(): void {
    this.applySnapshot(this.beforeData.map((row) => [...row]));
  }
}

export class CellStyleChange implements UndoableCommand {
  description: string;
  constructor(
    private batchUpdate: (updates: Array<{ row: number; col: number; style: CellStyleFields }>) => void,
    private cells: Array<{ row: number; col: number }>,
    private oldStyles: CellStyleFields[],
    private newStyles: CellStyleFields[],
  ) {
    this.description = `Style change (${cells.length} cells)`;
  }

  execute(): void {
    this.batchUpdate(this.cells.map((c, i) => ({ ...c, style: this.newStyles[i] })));
  }

  undo(): void {
    this.batchUpdate(this.cells.map((c, i) => ({ ...c, style: this.oldStyles[i] })));
  }
}
