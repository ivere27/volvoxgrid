/**
 * Edit lifecycle state machine.
 *
 * Tracks whether a cell is being edited and dispatches Edit RPC
 * commands to VolvoxGrid via protobuf.
 */

import {
  encodeEditStart,
  encodeEditCommit,
  encodeEditCancel,
} from "../proto/proto-utils.js";

export type EditPhase = "idle" | "editing";

export class EditStateMachine {
  private _phase: EditPhase = "idle";
  private _formulaMode = false;
  private _row: number = -1;
  private _col: number = -1;
  private _originalText: string = "";
  private _currentText: string = "";

  private wasm: any;
  private gridId: number;
  private readonly flushPendingDecisions: (() => void) | null;

  constructor(wasm: any, gridId: number, flushPendingDecisions?: () => void) {
    this.wasm = wasm;
    this.gridId = gridId;
    this.flushPendingDecisions = flushPendingDecisions ?? null;
  }

  get phase(): EditPhase { return this._phase; }
  get isEditing(): boolean { return this._phase === "editing"; }
  get isFormulaMode(): boolean { return this._formulaMode; }
  get row(): number { return this._row; }
  get col(): number { return this._col; }
  get originalText(): string { return this._originalText; }
  get currentText(): string { return this._currentText; }

  /** Sync local state to an already-active engine edit session without dispatching another start command. */
  syncActiveEdit(row: number, col: number, currentText: string, opts?: {
    formulaMode?: boolean;
  }): void {
    this._phase = "editing";
    this._row = row;
    this._col = col;
    this._originalText = currentText;
    this._currentText = currentText;
    this._formulaMode = opts?.formulaMode ?? currentText.trimStart().startsWith("=");
  }

  /** Start editing a cell. Returns true when the engine accepted the edit session. */
  startEdit(row: number, col: number, opts?: {
    selectAll?: boolean;
    caretEnd?: boolean;
    seedText?: string;
    currentText?: string;
    formulaMode?: boolean;
  }): boolean {
    if (this._phase === "editing") {
      const committed = this.commitEdit();
      if (committed?.canceled) {
        return false;
      }
    }

    this._row = row;
    this._col = col;
    this._originalText = opts?.currentText ?? "";
    this._currentText = opts?.seedText ?? this._originalText;
    this._phase = "editing";
    this._formulaMode =
      opts?.formulaMode
      ?? this._currentText.trimStart().startsWith("=");

    if (typeof this.wasm.volvox_grid_edit_pb === "function") {
      const req = encodeEditStart({
        gridId: this.gridId,
        row,
        col,
        selectAll: opts?.selectAll,
        caretEnd: opts?.caretEnd,
        seedText: opts?.seedText,
        formulaMode: this._formulaMode,
      });
      this.wasm.volvox_grid_edit_pb(req);
      this.flushPendingDecisions?.();
      if (typeof this.wasm.is_editing === "function" && this.wasm.is_editing(this.gridId) === 0) {
        this.reset();
        return false;
      }
    }
    return true;
  }

  /** Commit the current edit. Returns commit state or null if not editing. */
  commitEdit(text?: string): { oldText: string; newText: string; canceled: boolean } | null {
    if (this._phase !== "editing") return null;

    const oldText = this._originalText;
    const newText = text ?? this._currentText;

    if (typeof this.wasm.volvox_grid_edit_pb === "function") {
      const req = encodeEditCommit({ gridId: this.gridId, text });
      this.wasm.volvox_grid_edit_pb(req);
      this.flushPendingDecisions?.();
      if (typeof this.wasm.is_editing === "function" && this.wasm.is_editing(this.gridId) !== 0) {
        this._currentText = newText;
        this._formulaMode = newText.trimStart().startsWith("=");
        return { oldText, newText, canceled: true };
      }
    }

    this._phase = "idle";
    return { oldText, newText, canceled: false };
  }

  /** Cancel the current edit. */
  cancelEdit(): void {
    if (this._phase !== "editing") return;

    if (typeof this.wasm.volvox_grid_edit_pb === "function") {
      const req = encodeEditCancel(this.gridId);
      this.wasm.volvox_grid_edit_pb(req);
    }

    this._phase = "idle";
  }

  /** Update current text from engine's cell_edit_change event. */
  onEditTextChanged(text: string): void {
    if (this._phase === "editing") {
      this._currentText = text;
      this._formulaMode = text.trimStart().startsWith("=");
    }
  }

  /** Called when engine reports edit started (StartEditEvent). */
  onEngineStartEdit(row: number, col: number): void {
    this._phase = "editing";
    this._row = row;
    this._col = col;
    this._formulaMode = this._currentText.trimStart().startsWith("=");
  }

  /** Called when engine reports edit ended (AfterEditEvent). */
  onEngineAfterEdit(row: number, col: number, oldText: string, newText: string): void {
    this._phase = "idle";
    this._originalText = oldText;
    this._currentText = newText;
    this._formulaMode = false;
  }

  /** Reset state on destroy. */
  reset(): void {
    this._phase = "idle";
    this._row = -1;
    this._col = -1;
    this._originalText = "";
    this._currentText = "";
    this._formulaMode = false;
  }
}
